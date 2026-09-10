import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tecnigo/screens/admin_reportes_screen.dart';
import 'package:tecnigo/screens/admin_servicios_screen.dart';
import 'package:tecnigo/screens/admin_tecnicos_screen.dart';
import 'package:tecnigo/screens/admin_usuarios_screen.dart';
import 'package:tecnigo/screens/dashboard_screen.dart';
import 'package:tecnigo/screens/login_screen.dart';
import 'package:tecnigo/theme/app_colors.dart';
import 'package:tecnigo/widgets/drawer/menu_item.dart';
import 'package:tecnigo/widgets/drawer/profile_header.dart';

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            const ProfileHeader(rolLabel: 'Administrador'),
            const SizedBox(height: 15),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  MenuItem(
                    icon: Icons.home_outlined,
                    title: 'Inicio',
                    onTap: () => _abrir(context, const DashboardScreen()),
                  ),
                  MenuItem(
                    icon: Icons.people_outline,
                    title: 'Usuarios',
                    onTap: () => _abrir(context, const AdminUsuariosScreen()),
                  ),
                  MenuItem(
                    icon: Icons.engineering_outlined,
                    title: 'Técnicos',
                    onTap: () => _abrir(context, const AdminTecnicosScreen()),
                  ),
                  MenuItem(
                    icon: Icons.build_outlined,
                    title: 'Servicios',
                    onTap: () => _abrir(context, const AdminServiciosScreen()),
                  ),
                  MenuItem(
                    icon: Icons.report_problem_outlined,
                    title: 'Reportes',
                    onTap: () => _abrir(context, const AdminReportesScreen()),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            MenuItem(
              icon: Icons.logout,
              title: 'Cerrar sesión',
              color: Colors.red,
              onTap: () async {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
                await FirebaseAuth.instance.signOut();
              },
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  void _abrir(BuildContext context, Widget pantalla) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
  }
}
