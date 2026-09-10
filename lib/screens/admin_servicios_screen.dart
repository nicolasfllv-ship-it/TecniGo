import 'package:flutter/material.dart';
import 'package:tecnigo/widgets/admin_placeholder_screen.dart';

class AdminServiciosScreen extends StatelessWidget {
  const AdminServiciosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminPlaceholderScreen(
      titulo: 'Servicios',
      icono: Icons.build_outlined,
      descripcion:
          'El listado administrativo de servicios estará disponible próximamente.',
    );
  }
}
