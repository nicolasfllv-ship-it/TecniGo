import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'register_screen.dart';
import 'home_tecnico_screen.dart';
import 'cliente_main_screen.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool cargando = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> iniciarSesion() async {
    // Evita que dos toques rápidos disparen dos inicios de sesión
    // al mismo tiempo (una posible causa de comportamientos raros).
    if (cargando) return;

    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa correo y contraseña')),
      );
      return;
    }

    setState(() => cargando = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario no encontrado')),
        );
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario sin datos')),
        );
        return;
      }

      final rol = doc['rol'];

      if (!mounted) return;

      if (rol == 'cliente') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const ClienteMainScreen(),
          ),
        );
      } else if (rol == 'tecnico') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const HomeTecnicoScreen(),
          ),
        );
      } else if (rol == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const DashboardScreen(),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rol inválido')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String mensaje;
      if (e.code == 'network-request-failed') {
        mensaje = 'Sin conexión a internet. Verifica tu conexión e '
            'intenta de nuevo.';
      } else if (e.code == 'user-not-found' || e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        mensaje = 'Correo o contraseña incorrectos';
      } else {
        mensaje = e.message ?? 'Error al iniciar sesión';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje)),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inesperado: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TecniGo'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  kToolbarHeight -
                  MediaQuery.of(context).padding.top,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.build_circle,
                  size: 100,
                  color: Colors.blue,
                ),

                const SizedBox(height: 20),

                const Text(
                  'Iniciar Sesión',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 30),

                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 15),

                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: cargando ? null : iniciarSesion,
                    child: cargando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text('Iniciar Sesión'),
                  ),
                ),

                const SizedBox(height: 10),

                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: const Text('Crear una cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}