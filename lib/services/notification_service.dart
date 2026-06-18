import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Clé de navigation globale pour naviguer depuis les notifs (hors contexte)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Handler arrière-plan (doit être top-level)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Notification arriere-plan: ${message.notification?.title}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Clé globale pour afficher les SnackBars depuis n'importe où
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  // ID de la conversation actuellement ouverte (défini par ChatScreen)
  // → évite d'afficher une bannière pour la conv que l'utilisateur est en train de lire
  static String? currentConvId;

  // Listener Firestore pour les notifications in-app
  StreamSubscription<QuerySnapshot>? _convSubscription;
  DateTime? _listenerStartedAt;

  // ── Initialisation ──────────────────────────────────
  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Créer les canaux Android (obligatoire Android 8+)
    await _createAndroidChannels();

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // Rafraîchir le token FCM automatiquement (session persistante)
    _messaging.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('private')
            .doc('tokens')
            .set({'fcmToken': newToken}, SetOptions(merge: true));
        debugPrint('Token FCM rafraîchi automatiquement');
      }
    });

    // App lancée depuis une notif (état terminé)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App lancee via notification: ${initialMessage.data}');
      // Délai pour que le navigateur soit prêt
      Future.delayed(const Duration(seconds: 2), () {
        _navigateFromMessage(initialMessage);
      });
    }
  }

  // ── Canaux Android ─────────────────────────────────
  Future<void> _createAndroidChannels() async {
    final plugin = FlutterLocalNotificationsPlugin();
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await plugin.initialize(initSettings);

    final androidPlugin = plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'hec_messages',
        'Messages',
        description: 'Notifications pour les messages privés',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'hec_announcements',
        'Annonces',
        description: 'Notifications pour les annonces HEC Abidjan',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    debugPrint('Canaux Android créés : hec_messages, hec_announcements');
  }

  // ── Demander les permissions ────────────────────────
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    debugPrint('Permission notifications: ${settings.authorizationStatus}');
    return granted;
  }

  // ── Sauvegarder le token FCM ────────────────────────
  // Le token est stocké dans /users/{uid}/private/tokens (sous-collection privée)
  // pour qu'il ne soit lisible que par l'owner — pas par les autres utilisateurs.
  Future<void> saveToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('private')
            .doc('tokens')
            .set({'fcmToken': token}, SetOptions(merge: true));
        debugPrint('Token FCM sauvegarde');
      }
    } catch (e) {
      debugPrint('Erreur token FCM: $e');
    }
  }

  // ── Supprimer le token à la déconnexion ─────────────
  // On supprime le token FCM du compte qui se déconnecte pour éviter
  // qu'un autre utilisateur sur le même appareil reçoive ses notifications.
  Future<void> deleteToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('private')
          .doc('tokens')
          .set({'fcmToken': FieldValue.delete()}, SetOptions(merge: true));
      debugPrint('Token FCM supprime (deconnexion)');
    } catch (e) {
      debugPrint('Erreur suppression token FCM: $e');
    }
  }

  // ── Listener in-app : notifications sans Cloud Functions ──
  //
  // Écoute les conversations Firestore.
  // Quand un nouveau message arrive d'un autre utilisateur,
  // affiche une bannière SnackBar dans l'app.
  // Fonctionne app ouverte (foreground) uniquement.
  // Pour les notifications background/terminated → Cloud Functions requis.
  void startInAppListener(String uid) {
    stopInAppListener(); // Arrêter l'éventuel listener précédent
    _listenerStartedAt = DateTime.now();

    _convSubscription = FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.modified) continue;

        final data = change.doc.data() as Map<String, dynamic>;
        final convId = change.doc.id;
        final lastSenderId = data['lastSenderId'] as String? ?? '';
        final lastMsg = data['lastMessage'] as String? ?? '';
        final lastMsgTime = (data['lastMessageTime'] as Timestamp?)?.toDate();
        final unread = (data['msgUnread_$uid'] ?? 0) as int;

        // Ignorer si :
        // – c'est l'utilisateur lui-même qui a envoyé
        // – pas de message non lu
        // – message antérieur au démarrage du listener (évite les "faux" notifs au login)
        // – la conversation est actuellement ouverte
        if (lastSenderId == uid) continue;
        if (unread <= 0) continue;
        if (lastMsgTime == null ||
            _listenerStartedAt == null ||
            !lastMsgTime.isAfter(_listenerStartedAt!)) {
          continue;
        }
        if (convId == currentConvId) continue;

        // Récupérer le nom de l'expéditeur depuis participantNames
        final participantNames =
            Map<String, String>.from(data['participantNames'] ?? {});
        final senderName = participantNames[lastSenderId] ?? 'Nouveau message';

        _showInAppBanner(title: senderName, body: lastMsg);

        // Mettre à jour le timestamp pour ne pas re-notifier le même message
        _listenerStartedAt = lastMsgTime;
      }
    }, onError: (e) {
      debugPrint('Erreur listener conversations: $e');
    });
  }

  void stopInAppListener() {
    _convSubscription?.cancel();
    _convSubscription = null;
  }

  // ── Bannière in-app ────────────────────────────────
  void _showInAppBanner({required String title, required String body}) {
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1C3A6B),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.chat_bubble_outline,
                color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 14)),
                  if (body.isNotEmpty)
                    Text(body,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Topics ─────────────────────────────────────────
  Future<void> subscribeUserTopics({
    required String role,
    String? niveau,
    String? filiere,
  }) async {
    await _subscribe('tous_les_utilisateurs');
    switch (role) {
      case 'student':
        await _subscribe('etudiants_uniquement');
        if (niveau != null) await _subscribe(niveau);
        if (filiere != null &&
            filiere != 'Tronc commun' &&
            filiere != 'Commune') {
          await _subscribe(filiere);
        }
        break;
      case 'teacher':
        await _subscribe('enseignants_uniquement');
        break;
      case 'admin':
        await _subscribe('administration');
        break;
      case 'staff':
        await _subscribe('staff');
        break;
    }
  }

  Future<void> _subscribe(String topic) async {
    final clean = _cleanTopic(topic);
    await _messaging.subscribeToTopic(clean);
    debugPrint('Abonne: $clean');
  }

  Future<void> unsubscribeAllTopics({
    required String role,
    String? niveau,
    String? filiere,
  }) async {
    await _messaging.unsubscribeFromTopic('tous_les_utilisateurs');
    await _messaging.unsubscribeFromTopic(_cleanTopic(role));
    if (niveau != null) await _messaging.unsubscribeFromTopic(_cleanTopic(niveau));
    if (filiere != null) await _messaging.unsubscribeFromTopic(_cleanTopic(filiere));
  }

  // ── Notifications FCM (push réel) ─────────────────
  void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? 'HEC Connect';
    final body = message.notification?.body ?? '';
    debugPrint('Notification FCM premier plan: $title');
    _showInAppBanner(title: title, body: body);
  }

  void _handleNotificationOpen(RemoteMessage message) {
    debugPrint('Notification ouverte: ${message.data}');
    _navigateFromMessage(message);
  }

  void _navigateFromMessage(RemoteMessage message) {
    final type           = message.data['type'] ?? '';
    final announcementId = message.data['announcementId'] as String?;
    final convId         = message.data['convId'] as String?;

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    if (type == 'announcement' && announcementId != null) {
      // Aller sur l'écran Annonces
      nav.pushNamedAndRemoveUntil('/annonces', (route) => route.isFirst);
    } else if (convId != null) {
      // Aller sur la messagerie
      nav.pushNamedAndRemoveUntil('/messagerie', (route) => route.isFirst);
    }
  }

  String _cleanTopic(String topic) {
    return topic
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll("'", '')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ô', 'o')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u')
        .replaceAll('ç', 'c');
  }
}
