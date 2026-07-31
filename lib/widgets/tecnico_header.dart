import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tecnigo/theme/app_colors.dart';

/// Interruptor para que el técnico marque si está disponible o no
/// para recibir servicios nuevos. Se guarda en su propio documento
/// de 'users', en el campo 'disponible'.
class TecnicoDisponibilidad extends StatelessWidget {
  const TecnicoDisponibilidad({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final docRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: docRef.snapshots(),
      builder: (context, snapshot) {
        bool disponible = true;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          disponible = data['disponible'] ?? true;
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(15, 15, 15, 0),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Icon(
                disponible ? Icons.check_circle : Icons.pause_circle,
                color: disponible ? AppColors.success : AppColors.subtitle,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  disponible
                      ? "Estás disponible para recibir servicios"
                      : "No estás recibiendo servicios nuevos",
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Switch(
                value: disponible,
                activeColor: AppColors.success,
                onChanged: (valor) {
                  docRef.update({'disponible': valor});
                },
              ),
            ],
          ),
        );
      },
    );
  }
}