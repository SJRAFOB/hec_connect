// lib/services/auth_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'notification_service.dart';
import 'presence_service.dart';

const _kServerUrl = 'https://hec-notify-server.onrender.com';

class AuthService extends ChangeNotifier with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _firebaseUser;
  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  User? get firebaseUser => _firebaseUser;
  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _firebaseUser != null;
  String? get errorMessage => _errorMessage;
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  bool get isTeacher => _currentUser?.role == UserRole.teacher;

  AuthService() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Détecte la mise en arrière-plan / fermeture de l'app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final uid = _firebaseUser?.uid;
    if (uid == null) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        PresenceService.setOffline(uid);
        break;
      case AppLifecycleState.resumed:
        PresenceService.setOnline(uid);
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _onAuthStateChanged(User? user) async {
    _firebaseUser = user;
    if (user != null) {
      await _loadUserProfile(user.uid);
      // Démarrer les notifications in-app Firestore
      NotificationService().startInAppListener(user.uid);
      // Sauvegarder le token FCM à chaque démarrage (session persistante)
      // getToken() retourne null si les permissions ne sont pas accordées → sans effet
      NotificationService().saveToken().catchError(
        (e) => debugPrint('Token FCM background save error: $e'),
      );
    } else {
      _currentUser = null;
      NotificationService().stopInAppListener();
    }
    notifyListeners();
  }

  Future<void> _loadUserProfile(String uid) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.collectionUsers)
          .doc(uid)
          .get();
      if (doc.exists) {
        _currentUser = AppUser.fromMap(doc.data()!, uid);
      }
    } catch (e) {
      debugPrint('Erreur chargement profil: $e');
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String nom,
    required String prenom,
    required String matricule,
    String? filiere,
    String? niveau,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final newUser = AppUser(
        uid: credential.user!.uid,
        nom: nom.trim(),
        prenom: prenom.trim(),
        email: email.trim(),
        matricule: matricule.trim(),
        role: UserRole.student,
        filiere: filiere,
        niveau: niveau,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(AppConstants.collectionUsers)
          .doc(credential.user!.uid)
          .set(newUser.toMap());

      _currentUser = newUser;
      await PresenceService.setOnline(credential.user!.uid);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Une erreur est survenue.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerTeacher({
    required String email,
    required String password,
    required String nom,
    required String prenom,
    List<String> matieres = const [],
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;
      final idToken = await credential.user!.getIdToken();

      // Écriture via serveur (Admin SDK bypass les règles Firestore)
      final serverError = await _createProfileOnServer(
        idToken: idToken!,
        uid: uid,
        nom: nom.trim(),
        prenom: prenom.trim(),
        email: email.trim(),
        role: 'teacher',
        poste: 'Professeur',
        matieres: matieres,
      );
      if (serverError != null) throw Exception(serverError);

      final newUser = AppUser(
        uid: uid,
        nom: nom.trim(),
        prenom: prenom.trim(),
        email: email.trim(),
        matricule: '',
        role: UserRole.teacher,
        matieres: matieres,
        createdAt: DateTime.now(),
      );

      _currentUser = newUser;
      await PresenceService.setOnline(uid);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Une erreur est survenue.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerAdmin({
    required String email,
    required String password,
    required String nom,
    required String prenom,
    required String poste,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;
      final idToken = await credential.user!.getIdToken();
      final isStaff = AppConstants.postesStaff.contains(poste);
      final roleStr = isStaff ? 'staff' : 'admin';

      // Écriture via serveur (Admin SDK bypass les règles Firestore)
      final serverError = await _createProfileOnServer(
        idToken: idToken!,
        uid: uid,
        nom: nom.trim(),
        prenom: prenom.trim(),
        email: email.trim(),
        role: roleStr,
        poste: poste,
      );
      if (serverError != null) throw Exception(serverError);

      final newUser = AppUser(
        uid: uid,
        nom: nom.trim(),
        prenom: prenom.trim(),
        email: email.trim(),
        matricule: '',
        role: isStaff ? UserRole.staff : UserRole.admin,
        poste: poste,
        createdAt: DateTime.now(),
      );

      _currentUser = newUser;
      await PresenceService.setOnline(uid);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Une erreur est survenue.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Crée le profil utilisateur via le serveur Render (Admin SDK).
  /// Retourne null si succès, un message d'erreur sinon.
  Future<String?> _createProfileOnServer({
    required String idToken,
    required String uid,
    required String nom,
    required String prenom,
    required String email,
    required String role,
    required String poste,
    List<String> matieres = const [],
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_kServerUrl/createUserProfile'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'idToken': idToken,
              'nom': nom,
              'prenom': prenom,
              'email': email,
              'role': role,
              'poste': poste,
              if (matieres.isNotEmpty) 'matieres': matieres,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['error']?.toString() ?? 'Erreur serveur';
    } catch (e) {
      return 'Impossible de joindre le serveur : $e';
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await _loadUserProfile(result.user!.uid);

      // Bloquer la connexion si le compte est désactivé
      if (_currentUser?.isDisabled == true) {
        await _auth.signOut();
        _errorMessage = 'Votre compte a été désactivé. Contactez un administrateur.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await PresenceService.setOnline(result.user!.uid);

      if (_currentUser != null) {
        try {
          final notif = NotificationService();
          final granted = await notif.requestPermission();
          if (granted) {
            await notif.saveToken();
            await notif.subscribeUserTopics(
              role: _currentUser!.role.name,
              niveau: _currentUser!.niveau,
              filiere: _currentUser!.filiere,
            );
          }
        } catch (e) {
          debugPrint('Erreur init notifications: $e');
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Une erreur est survenue.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    NotificationService().stopInAppListener();
    try {
      await NotificationService().deleteToken();
    } catch (e