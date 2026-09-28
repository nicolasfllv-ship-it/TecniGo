import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CurrentUserService {
  CurrentUserService._();

  static final CurrentUserService instance = CurrentUserService._();

  String? nombre;
  String? email;
  String? fotoBase64;

  bool _cargado = false;

  bool get cargado => _cargado;

  Future<void> cargar({bool forzar = false}) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      limpiar();
      return;
    }

    if (_cargado && !forzar) {
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data() ?? {};

      nombre = (data['nombre'] ?? '').toString().trim();
      email = (data['email'] ?? user.email ?? '').toString().trim();
      fotoBase64 = (data['fotoBase64'] ?? '').toString();
    } else {
      nombre = '';
      email = user.email ?? '';
      fotoBase64 = '';
    }

    _cargado = true;
  }

  void actualizar({
    String? nuevoNombre,
    String? nuevoEmail,
    String? nuevaFotoBase64,
  }) {
    if (nuevoNombre != null) {
      nombre = nuevoNombre.trim();
    }

    if (nuevoEmail != null) {
      email = nuevoEmail.trim();
    }

    if (nuevaFotoBase64 != null) {
      fotoBase64 = nuevaFotoBase64;
    }

    _cargado = true;
  }

  Uint8List? obtenerFotoBytes() {
    final foto = fotoBase64;

    if (foto == null || foto.isEmpty) {
      return null;
    }

    try {
      return base64Decode(foto);
    } catch (_) {
      return null;
    }
  }

  void limpiar() {
    nombre = null;
    email = null;
    fotoBase64 = null;
    _cargado = false;
  }
}