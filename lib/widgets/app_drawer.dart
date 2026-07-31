import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tecnigo/theme/app_colors.dart';

import 'drawer/profile_header.dart';
import 'drawer/menu_item.dart';
import 'package:tecnigo/screens/historial_screen.dart';
import 'package:tecnigo/screens/configuracion_screen.dart';
import 'package:tecnigo/screens/soporte_screen.dart';
import 'package:tecnigo/screens/login_screen.dart';

class AppDrawer extends StatelessWidget {
  final VoidCallback? onInicio;
  final VoidCallback? onMisServicios;

  const AppDrawer({
    super.key,
    this.onInicio,
    this.onMisServicios,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [

            const ProfileHeader(),

            const SizedBox(height: 15),

            // Envuelto en Expanded + ListView para que, si el contenido
            // no cabe en pantallas más pequeñas, se pueda desplazar en
            // vez de desbordarse fuera de la pantalla.
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  MenuItem(
                    icon: Icons.home_outlined,
                    title: "Inicio",
                    onTap: () {
                      Navigator.pop(context);
                      onInicio?.call();
                    },
                  ),

                  MenuItem(
                    icon: Icons.build_outlined,
                    title: "Mis servicios",
                    onTap: () {
                      Navigator.pop(context);
                      onMisServicios?.call();
                    },
                  ),

                  MenuItem(
                    icon: Icons.history,
                    title: "Historial",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const HistorialScreen()),
                      );
                    },
                  ),

                  MenuItem(
                    icon: Icons.settings_outlined,
                    title: "Configuración",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ConfiguracionScreen()),
                      );
                    },
                  ),

                  MenuItem(
                    icon: Icons.support_agent,
                    title: "Soporte",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SoporteScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            MenuItem(
              icon: Icons.logout,
              title: "Cerrar sesión",
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
}