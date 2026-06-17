import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // ── Initialisation ──────────────────────────────────
  Future<void> initialize() async {
    // Enregistrer le handler arrière-plan
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Option iOS : afficher les notifications en premier plan
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Écouter les notifications en premier plan
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // App ouverte depuis une notification (background → foreground)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // App lancée depuis une notification (terminated)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App lancee via notification: ${initialMessage.data}');
    }
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

  // ── Sauvegarder le token FCM dans Firestore ─────────
  Future<void> saveToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token});
        debugPrint('Token FCM sauvegarde');
      }
      // Actualiser le token si renouvelé
      _messaging.onTokenRefresh.listen((newToken) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': newToken});
      });
    } catch (e) {
      debugPrint('Erreur token FCM: $e');
    }
  }

  // ── Supprimer le token à la déconnexion ─────────────
  Future<void> deleteToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _messaging.deleteToken();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcmToken': FieldValue.delete()});
    } catch (e) {
      debugPrint('Erreur suppression token: $e');
    }
  }

  // ── S'abonner aux topics selon le rôle ─────────────
  Future<void> subscribeUserTopics({
    required String role,
    String? niveau,
    String? filiere,
  }) async {
    // Topic universel
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

  // ── Afficher une bannière en premier plan ───────────
  void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? 'HEC Connect';
    final body = message.notification?.body ?? '';
    debugPrint('Notification premier plan: $title');

    // Afficher une SnackBar colorée
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1C3A6B),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.notifications_active,
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

  void _handleNotificationOpen(RemoteMessage message) {
    debugPrint('Notification ouverte: ${message.data}');
  }

  // Nettoyer le nom du topic (pas de caractères spéciaux)
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