import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tecnigo/theme/app_colors.dart';

class ClienteHeader extends StatelessWidget {
  const ClienteHeader({super.key});

  String obtenerSaludo() {
    final hora = DateTime.now().hour;

    if (hora < 12) {
      return "Buenos días";
    } else if (hora < 18) {
      return "Buenas tardes";
    } else {
      return "Buenas noches";
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Text(
          "${obtenerSaludo()} 👋",
          style: const TextStyle(
            fontSize: 18,
            color: AppColors.subtitle,
          ),
        ),

        const SizedBox(height: 8),

        FutureBuilder<DocumentSnapshot>(
          future: user == null
              ? null
              : FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
          builder: (context, snapshot) {
            String nombre = "Usuario";
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              if ((data['nombre'] ?? '').toString().isNotEmpty) {
                nombre = data['nombre'];
              }
            }
            return Text(
              nombre,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),

        const SizedBox(height: 5),

        const Text(
          "¿Qué necesitas hoy?",
          style: TextStyle(
            fontSize: 18,
            color: AppColors.subtitle,
          ),
        ),
      ],
    );
  }
}