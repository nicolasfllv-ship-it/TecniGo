import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tecnigo/theme/app_colors.dart';
import 'package:tecnigo/widgets/scanner_frame.dart';
import 'editar_perfil_screen.dart';
import 'login_screen.dart';

class MiCuentaTecnicoScreen extends StatelessWidget {
  const MiCuentaTecnicoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: user == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.tecnicoAccent))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .get(),
                  builder: (context, snapshot) {
                    String nombre = user.email ?? '';
                    Uint8List? fotoBytes;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data =
                          snapshot.data!.data() as Map<String, dynamic>;
                      if ((data['nombre'] ?? '').toString().isNotEmpty) {
                        nombre = data['nombre'];
                      }
                      if ((data['fotoBase64'] ?? '').toString().isNotEmpty) {
                        try {
                          fotoBytes = base64Decode(data['fotoBase64']);
                        } catch (_) {}
                      }
                    }

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 26),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const EditarPerfilScreen()),
                              );
                            },
                            child: ScannerFrame(
                              tamano: 14,
                              grosor: 2,
                              color: AppColors.tecnicoAccent,
                              child: CircleAvatar(
                                radius: 46,
                                backgroundColor: AppColors.background,
                                backgroundImage: fotoBytes != null
                                    ? MemoryImage(fotoBytes)
                                    : null,
                                child: fotoBytes == null
                                    ? const Icon(
                                        Icons.engineering,
                                        size: 46,
                                        color: AppColors.tecnicoAccent,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            nombre,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const EditarPerfilScreen()),
                              );
                            },
                            child: const Text(
                              'Editar perfil',
                              style: TextStyle(color: AppColors.tecnicoAccent),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Calificación promedio real, calculada de las
                // calificaciones que los clientes le han dejado.
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('calificaciones')
                      .where('tecnicoId', isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.tecnicoAccent),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    double promedio = 0;
                    if (docs.isNotEmpty) {
                      final suma = docs.fold<int>(
                        0,
                        (acumulado, doc) =>
                            acumulado + (doc['calificacion'] as num).toInt(),
                      );
                      promedio = suma / docs.length;
                    }

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                docs.isEmpty
                                    ? 'Sin calificaciones aún'
                                    : promedio.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (docs.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 28),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${docs.length} calificación(es) recibida(s)',
                            style:
                                const TextStyle(color: AppColors.subtitle),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                      await FirebaseAuth.instance.signOut();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text("Cerrar sesión"),
                  ),
                ),
              ],
            ),
    );
  }
}