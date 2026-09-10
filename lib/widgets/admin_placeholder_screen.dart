import 'package:flutter/material.dart';
import 'package:tecnigo/theme/app_colors.dart';

class AdminPlaceholderScreen extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final String descripcion;

  const AdminPlaceholderScreen({
    super.key,
    required this.titulo,
    required this.icono,
    required this.descripcion,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 52, color: AppColors.accent),
              const SizedBox(height: 18),
              Text(
                'Próximamente',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                descripcion,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.subtitle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
