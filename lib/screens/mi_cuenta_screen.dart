import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tecnigo/screens/historial_screen.dart';
import 'package:tecnigo/screens/configuracion_screen.dart';
import 'package:tecnigo/screens/editar_perfil_screen.dart';
import 'package:tecnigo/theme/app_colors.dart';
import 'package:tecnigo/widgets/scanner_frame.dart';
import 'login_screen.dart';

class MiCuentaScreen extends StatelessWidget {
  const MiCuentaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mi cuenta'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: [
          FutureBuilder<DocumentSnapshot>(
            future: user == null
                ? null
                : FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .get(),
            builder: (context, snapshot) {
              String nombre = user?.email ?? '';
              Uint8List? fotoBytes;
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
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
                              builder: (_) => const EditarPerfilScreen()),
                        );
                      },
                      child: ScannerFrame(
                      tamano: 14,
                      grosor: 2,
                      child: CircleAvatar(
                        radius: 46,
                        backgroundColor: AppColors.background,
                        backgroundImage: fotoBytes != null
                            ? MemoryImage(fotoBytes)
                            : null,
                        child: fotoBytes == null
                            ? const Icon(
                                Icons.person,
                                size: 50,
                                color: AppColors.primary,
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
                    if (user?.email != null && user!.email != nombre) ...[
                      const SizedBox(height: 4),
                      Text(
                        user.email!,
                        style: const TextStyle(
                          color: AppColors.subtitle,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EditarPerfilScreen()),
                        );
                      },
                      child: const Text(
                        'Editar perfil',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 26),

          _OpcionCuenta(
            icono: Icons.history,
            titulo: 'Historial',
            subtitulo: 'Tus servicios anteriores',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistorialScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _OpcionCuenta(
            icono: Icons.settings_outlined,
            titulo: 'Configuración',
            subtitulo: 'Cuenta, notificaciones y más',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ConfiguracionScreen()),
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
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
                await FirebaseAuth.instance.signOut();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpcionCuenta extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  const _OpcionCuenta({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                child: Icon(icono, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      style: const TextStyle(
                        color: AppColors.subtitle,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: AppColors.subtitle, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}