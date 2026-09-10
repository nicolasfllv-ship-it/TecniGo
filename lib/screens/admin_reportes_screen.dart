import 'package:flutter/material.dart';
import 'package:tecnigo/widgets/admin_placeholder_screen.dart';

class AdminReportesScreen extends StatelessWidget {
  const AdminReportesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminPlaceholderScreen(
      titulo: 'Reportes',
      icono: Icons.report_problem_outlined,
      descripcion: 'Los servicios reportados estarán disponibles próximamente.',
    );
  }
}
