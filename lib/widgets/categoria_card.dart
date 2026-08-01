import 'package:flutter/material.dart';
import 'package:tecnigo/theme/app_colors.dart';

class CategoriaCard extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color color;
  final bool seleccionado;
  final VoidCallback onTap;

  const CategoriaCard({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.color,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 15),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: seleccionado ? AppColors.primary : AppColors.border,
          width: seleccionado ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        leading: Icon(
          icono,
          color: color,
          size: 35,
        ),
        title: Text(
          titulo,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.text,
          ),
        ),
        subtitle: Text(
          subtitulo,
          style: const TextStyle(color: AppColors.subtitle),
        ),
        trailing: seleccionado
            ? const Icon(
                Icons.check_circle,
                color: AppColors.primary,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}