import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'calificar_tecnico_screen.dart';
import 'seguimiento_screen.dart';

class MisServiciosScreen extends StatelessWidget {
  const MisServiciosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('servicios')
          .where('clienteId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final servicios = snapshot.data!.docs;

          if (servicios.isEmpty) {
            return const Center(
              child: Text('No tienes solicitudes registradas'),
            );
          }

          return ListView.builder(
            itemCount: servicios.length,
            itemBuilder: (context, index) {
              final servicio = servicios[index];

              return Card(
                margin: const EdgeInsets.all(10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.build, color: Colors.blue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              servicio['tipoServicio'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Text(
                        servicio['descripcion'],
                        style: const TextStyle(fontSize: 16),
                      ),

                      const Divider(height: 25),

                      Text(
                        "Estado: ${servicio['estado']}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      if (servicio.data().toString().contains('tecnicoEmail'))
                        Text(
                          "Técnico: ${servicio['tecnicoEmail']}",
                        ),
                    if (servicio.data().toString().contains('fechaAceptacion'))
  Text(
    "Fecha de aceptación: ${(servicio['fechaAceptacion'] as Timestamp).toDate()}",
  ),

const SizedBox(height: 15),

if (servicio['estado'] == 'aceptado' ||
    servicio['estado'] == 'en camino' ||
    servicio['estado'] == 'trabajando')
  SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      icon: const Icon(Icons.map),
      label: const Text("Ver seguimiento en el mapa"),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SeguimientoScreen(
              servicioId: servicio.id,
              tecnicoId: servicio['tecnicoId'],
              clienteLat: (servicio['lat'] as num).toDouble(),
              clienteLng: (servicio['lng'] as num).toDouble(),
              tipoServicio: servicio['tipoServicio'],
            ),
          ),
        );
      },
    ),
  ),

if (servicio['estado'] == 'finalizado' &&
    !(servicio.data() as Map<String, dynamic>)
        .containsKey('calificado'))
  SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      icon: const Icon(Icons.star),
      label: const Text("Calificar técnico"),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CalificarTecnicoScreen(
              servicioId: servicio.id,
              tecnicoId: servicio['tecnicoId'],
            ),
          ),
        );
      },
    ),
  ),

if ((servicio.data() as Map<String, dynamic>)
        .containsKey('calificado') &&
    servicio['calificado'] == true)
  const Padding(
    padding: EdgeInsets.only(top: 10),
    child: Row(
      children: [
        Icon(Icons.check_circle, color: Colors.green),
        SizedBox(width: 8),
        Text(
          "Este servicio ya fue calificado",
          style: TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  ),  
                    ],
                  ),
                ),
              );
            },
          );
        },
    );
  }
}