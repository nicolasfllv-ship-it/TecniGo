import 'package:flutter/material.dart';

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
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 15),
      child: ListTile(
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
          ),
        ),
        subtitle: Text(subtitulo),
        trailing: seleccionado
            ? const Icon(
                Icons.check_circle,
                color: Colors.green,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}