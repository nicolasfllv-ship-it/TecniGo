import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tecnigo/theme/app_colors.dart';

/// Muestra los servicios que el cliente ya completó (estado 'finalizado'),
/// a diferencia de "Mis servicios" que muestra los activos/en curso.
class HistorialScreen extends StatelessWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('servicios')
                  .where('clienteId', isEqualTo: user.uid)
                  .where('estado', isEqualTo: 'finalizado')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final servicios = snapshot.data!.docs;

                if (servicios.isEmpty) {
                  return const Center(
                    child: Text('Todavía no tienes servicios completados'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: servicios.length,
                  itemBuilder: (context, index) {
                    final data =
                        servicios[index].data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.check_circle,
                            color: AppColors.success),
                        title: Text(data['tipoServicio'] ?? ''),
                        subtitle: Text(data['descripcion'] ?? ''),
                        trailing: data['tecnicoEmail'] != null
                            ? Text(
                                data['tecnicoEmail'],
                                style: const TextStyle(fontSize: 12),
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}