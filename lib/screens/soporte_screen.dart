import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SoporteScreen extends StatelessWidget {
  const SoporteScreen({super.key});

  static const _preguntas = [
    (
      '¿Cómo solicito un servicio?',
      'Desde el inicio, toca "Solicitar asistencia", elige el tipo de '
          'servicio y describe tu problema. Un técnico cercano lo verá '
          'y podrá aceptarlo.',
    ),
    (
      '¿Cómo sé cuándo llega el técnico?',
      'Una vez un técnico acepta tu solicitud, puedes ver su ubicación '
          'en vivo y el tiempo estimado de llegada desde "Mis servicios".',
    ),
    (
      '¿Puedo cancelar un servicio?',
      'Por ahora esta opción está en desarrollo. Si necesitas cancelar, '
          'contáctanos directamente por correo.',
    ),
  ];

  Future<void> _contactar() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'soporte@tecnigo.com',
      query: 'subject=Ayuda con TecniGo',
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