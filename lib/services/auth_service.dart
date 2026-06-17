// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'notification_service.dart';
import 'presence_service.dart';

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

      final newUser = AppUser(
        uid: credential.user!.uid,
        nom: nom.trim(),
        prenom: prenom.trim(),
        email: email.trim(),
        matricule: '',
        role: UserRole.teacher,
        matieres: matieres,
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

      final isStaff = AppConstants.postesStaff.contains(poste);
      final role = isStaff ? UserRole.staff : UserRole.admin;

      final newUser = AppUser(
        uid: credential.user!.uid,
        nom: nom.trim(),
        prenom: prenom.trim(),
        email: email.trim(),
        matricule: '',
        role: role,
        poste: poste,
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
    } catch (e) {
      debugPrint('Erreur suppression token: $e');
    }
    if (_firebaseUser != null) {
      await PresenceService.setOffline(_firebaseUser!.uid);
    }
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile(AppUser updated) async {
    try {
      await _firestore
          .collection(AppConstants.collectionUsers)
          .doc(updated.uid)
          .update(updated.toMap());
      _currentUser = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la mise à jour.';
      notifyListeners();
      return false;
    }
  }

  /// Met à jour _currentUser en mémoire sans toucher Firestore.
  /// Utile quand Firestore a déjà été mis à jour séparément.
  void updateCurrentUserInMemory(AppUser updated) {
    _currentUser = updated;
    notifyListeners();
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Aucun compte trouvé avec cet email.';
      case 'wrong-password':
        return 'Mot de passe incorrect.';
      case 'invalid-credential':
        return 'Email ou mot de passe incorrect.';
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé.';
      case 'weak-password':
        return 'Mot de passe trop faible (min. 6 caractères).';
      