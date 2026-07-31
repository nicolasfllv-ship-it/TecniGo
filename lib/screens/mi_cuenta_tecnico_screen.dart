import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tecnigo/theme/app_colors.dart';
import 'login_screen.dart';

class MiCuentaTecnicoScreen extends StatelessWidget {
  const MiCuentaTecnicoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const CircleAvatar(
                  radius: 50,
                  child: Icon(Icons.engineering, size: 50),
                ),
                const SizedBox(height: 15),
                Center(
                  child: FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .get(),
                    builder: (context, snapshot) {
                      String nombre = user.email ?? '';
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data =
                            snapshot.data!.data() as Map<String, dynamic>;
                        if ((data['nombre'] ?? '').toString().isNotEmpty) {
                          nombre = data['nombre'];
                        }
                      }
                      return Text(
                        nombre,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 30),

                // Calificación promedio real, calculada de las
                // calificaciones que los clientes le han dejado.
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('calificaciones')
                      .where('tecnicoId', isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    double promedio = 0;
                    if (docs.isNotEmpty) {
                      final suma = docs.fold<int>(
                        0,
                        (acumulado, doc) =>
                            acumulado + (doc['calificacion'] as num).toInt(),
                      );
                      promedio = suma / docs.length;
                    }

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  docs.isEmpty
                                      ? 'Sin calificaciones aún'
                                      : promedio.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (docs.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.star,
                                      color: Colors.amber, size: 28),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${docs.length} calificación(es) recibida(s)',
                              style: const TextStyle(
                                  color: AppColors.subtitle),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 30),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 55),
                  ),
                  onPressed: () async {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                    await FirebaseAuth.instance.signOut();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text("Cerrar sesión"),
                ),
              ],
            ),
    );
  }
}