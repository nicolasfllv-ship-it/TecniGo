import 'package:flutter/material.dart';
import 'package:tecnigo/theme/app_colors.dart';
import 'package:tecnigo/widgets/scanner_frame.dart';

class SolicitarAsistenciaCard extends StatelessWidget {
  final VoidCallback onTap;

  const SolicitarAsistenciaCard({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ScannerFrame(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.build_circle_rounded,
                  color: AppColors.primary,
                  size: 70,
                ),

                const SizedBox(height: 20),

                Text(
                  "Solicitar asistencia",
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Toca aquí para comenzar",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.subtitle,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}