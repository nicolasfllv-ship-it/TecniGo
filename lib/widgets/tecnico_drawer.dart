import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tecnigo/theme/app_colors.dart';

import 'drawer/profile_header.dart';
import 'drawer/menu_item.dart';
import 'package:tecnigo/screens/mis_servicios_tecnico_screen.dart';
import 'package:tecnigo/screens/mi_cuenta_tecnico_screen.dart';
import 'package:tecnigo/screens/configuracion_screen.dart';
import 'package:tecnigo/screens/soporte_tecnico_screen.dart';
import 'package:tecnigo/screens/login_screen.dart';

class TecnicoDrawer extends StatelessWidget {
  const TecnicoDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [

            const ProfileHeader(rolLabel: "Técnico"),

            const SizedBox(height: 15),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  MenuItem(
                    icon: Icons.home_outlined,
                    title: "Inicio",
                    onTap: () => Navigator.pop(context),
                  ),

                  MenuItem(
                    icon: Icons.build_outlined,
                    title: "Mis servicios",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MisServiciosTecnicoScreen(),
                        ),
                      );
                    },
                  ),

                  MenuItem(
                    icon: Icons.person_outline,
                    title: "Mi cuenta",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MiCuentaTecnicoScreen(),
                        ),
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
                          builder: (_) => const ConfiguracionScreen(),
                        ),
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
                        MaterialPageRoute(builder: (_) => const SoporteTecnicoScreen()),
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