import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SoporteTecnicoScreen extends StatelessWidget {
  const SoporteTecnicoScreen({super.key});

  static const _preguntas = [
    (
      '¿Cómo veo los servicios disponibles?',
      'En el Home verás los servicios pendientes ordenados por '
          'cercanía, dentro de un radio de 20 km. Si no ves ninguno, '
          'revisa que tu ubicación esté activada.',
    ),
    (
      '¿Por qué no me llegan servicios?',
      'Puede ser porque desactivaste el interruptor de "Disponible" '
          'en el Home, porque no hay solicitudes cerca de ti en este '
          'momento, o porque el GPS está desactivado.',
    ),
    (
      '¿Qué hago después de aceptar un servicio?',
      'Ve avanzando el estado desde "Mis servicios asignados": '
          '"En camino" cuando salgas, "Iniciar trabajo" cuando llegues, '
          'y "Finalizar servicio" cuando termines.',
    ),
    (
      '¿Cómo veo mi calificación?',
      'Desde el menú, entra a "Mi cuenta". Ahí ves el promedio de '
          'las calificaciones que los clientes te han dejado.',
    ),
  ];

  Future<void> _contactar() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'soporte@tecnigo.com',
      query: 'subject=Ayuda con TecniGo (Técnico)',
    );
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Soporte')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Preguntas frecuentes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ..._preguntas.map(
            (p) => ExpansionTile(
              title: Text(p.$1),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(p.$2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _contactar,
            icon: const Icon(Icons.email_outlined),
            label: const Text('Contactar soporte'),
          ),
        ],
      ),
    );
  }
}