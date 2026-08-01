import 'package:flutter/material.dart';
import 'package:tecnigo/theme/app_colors.dart';

class DashboardCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icono;
  final Color color;

  const DashboardCard({
    super.key,
    required this.titulo,
    required this.valor,
    required this.icono,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shadowColor: color.withOpacity(0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            CircleAvatar(
              radius: 26,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(
                icono,
                color: color,
                size: 28,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              valor,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              titulo,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.subtitle,
              ),
            ),

          ],
        ),
      ),
    );
  }
}