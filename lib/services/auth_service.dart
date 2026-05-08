import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum UserRole { admin, user }

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final ValueNotifier<User?> currentUser = ValueNotifier(null);
  UserRole _role = UserRole.user;

  UserRole get role => _role;
  bool get isAdmin => _role == UserRole.admin;
  bool get isLoggedIn => currentUser.value != null;

  void init() {
    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        await _loadRole(user.uid);
      } else {
        _role = UserRole.user;
      }
      currentUser.value = user;
    });
  }

  Future<void> _loadRole(String uid) async {
    try {
      final doc = await _db.collection('usuarios').doc(uid).get();
      if (doc.exists && doc.data()?['role'] == 'admin') {
        _role = UserRole.admin;
      } else {
        _role = UserRole.user;
      }
    } catch (_) {
      _role = UserRole.user;
    }
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Registra un nuevo usuario y guarda su perfil en Firestore
  Future<void> signUp({
    required String email,
    required String password,
    required String nombre,
    required String apellido,
    required String telefono,
    required String equipo, // equipo favorito o al que pertenece
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;

    // Actualiza el displayName en Firebase Auth
    await credential.user!.updateDisplayName('$nombre $apellido');

    // Guarda el perfil completo en Firestore
    await _db.collection('usuarios').doc(uid).set({
      'uid': uid,
      'nombre': nombre.trim(),
      'apellido': apellido.trim(),
      'nombreCompleto': '${nombre.trim()} ${apellido.trim()}',
      'email': email.trim(),
      'telefono': telefono.trim(),
      'equipoFavorito': equipo.trim(),
      'role': 'user', // siempre usuario por defecto
      'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
    });
  }

  /// Actualiza lastLogin al entrar
  Future<void> updateLastLogin() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('usuarios').doc(uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
