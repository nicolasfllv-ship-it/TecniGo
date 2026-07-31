import 'package:flutter/material.dart';

class SolicitarAsistenciaCard extends StatelessWidget {
  final VoidCallback onTap;

  const SolicitarAsistenciaCard({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: const Color(0xFF27272A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.build_circle_rounded,
              color: Colors.white,
              size: 70,
            ),

            SizedBox(height: 20),

            Text(
              "Solicitar asistencia",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 8),

            Text(
              "Toca aquí para comenzar",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}