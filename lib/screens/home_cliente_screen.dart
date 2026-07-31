import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'solicitar_servicio_screen.dart';
import 'package:tecnigo/widgets/cliente_header.dart';
import 'package:tecnigo/widgets/solicitar_asistencia_card.dart';
import 'package:tecnigo/widgets/home/servicio_actual_card.dart';
import 'package:tecnigo/widgets/home/service_categories.dart';

class HomeClienteScreen extends StatelessWidget {
  const HomeClienteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const ClienteHeader(),

            const SizedBox(height: 30),

            SolicitarAsistenciaCard(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SolicitarServicioScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 25),

            const ServicioActualCard(),

            const SizedBox(height: 25),

            const ServiceCategories(),
          ],
        ),
      ),
    );
  }
}