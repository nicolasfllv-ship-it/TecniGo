import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Pantalla de configuración de la cuenta. De momento incluye solo
/// las opciones que sí están conectadas a algo real (cambiar contraseña),
/// para no mostrar controles que no hacen nada.
class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  bool enviando = false;

  Future<void> _cambiarContrasena() async {
    if (enviando) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;

    setState(() => enviando = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Te enviamos un correo a ${user.email} para cambiar tu contraseña',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Correo de la cuenta'),
              subtitle: Text(user?.email ?? ''),
            ),
          ),
          Card(
            child: ListTile(
              leading: enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_outline),
              title: const Text('Cambiar contraseña'),
              subtitle: const Text('Te enviaremos un correo para restablecerla'),
              onTap: enviando ? null : _cambiarContrasena,
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'TecniGo · versión 1.0',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}