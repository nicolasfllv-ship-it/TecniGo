import 'package:flutter/material.dart';
import 'package:tecnigo/widgets/admin_placeholder_screen.dart';

class AdminUsuariosScreen extends StatelessWidget {
  const AdminUsuariosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminPlaceholderScreen(
      titulo: 'Usuarios',
      icono: Icons.people_outline,
      descripcion: 'La gestión de usuarios estará disponible próximamente.',
    );
  }
}
