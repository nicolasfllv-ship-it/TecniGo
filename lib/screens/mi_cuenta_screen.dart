import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tecnigo/screens/historial_screen.dart';
import 'package:tecnigo/screens/configuracion_screen.dart';
import 'login_screen.dart';

class MiCuentaScreen extends StatelessWidget {
  const MiCuentaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return ListView(
        padding: const EdgeInsets.all(20),
        children: [

          const CircleAvatar(
            radius: 50,
            child: Icon(
              Icons.person,
              size: 55,
            ),
          ),

          const SizedBox(height: 15),

          Center(
            child: FutureBuilder<DocumentSnapshot>(
              future: user == null
                  ? null
                  : FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .get(),
              builder: (context, snapshot) {
                String nombre = user?.email ?? "";
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

          Card(
            child: ListTile(
              leading: const Icon(Icons.history),
              title: const Text("Historial"),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistorialScreen()),
                );
              },
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Configuración"),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ConfiguracionScreen()),
                );
              },
            ),
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
    );
  }
}