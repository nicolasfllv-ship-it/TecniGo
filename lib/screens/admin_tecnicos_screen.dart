import 'package:flutter/material.dart';
import 'package:tecnigo/widgets/admin_placeholder_screen.dart';

class AdminTecnicosScreen extends StatelessWidget {
  const AdminTecnicosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminPlaceholderScreen(
      titulo: 'Técnicos',
      icono: Icons.engineering_outlined,
      descripcion:
          'El detalle y métricas de técnicos estarán disponibles próximamente.',
    );
  }
}
