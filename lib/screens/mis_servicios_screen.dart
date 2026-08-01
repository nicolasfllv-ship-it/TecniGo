import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'calificar_tecnico_screen.dart';
import 'seguimiento_screen.dart';

class MisServiciosScreen extends StatefulWidget {
  const MisServiciosScreen({super.key});

  @override
  State<MisServiciosScreen> createState() => _MisServiciosScreenState();
}

class _MisServiciosScreenState extends State<MisServiciosScreen> {
  // Servicios que se están cancelando en este momento (para bloquear
  // el botón y no permitir doble toque).
  final Set<String> _cancelando = {};

  Future<void> _confirmarCancelar(String servicioId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar este servicio?'),
        content: const Text(
          'Esta acción no se puede deshacer. El servicio quedará '
          'cancelado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, mantenerlo'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sí, cancelar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _cancelando.add(servicioId));

    try {
      await FirebaseFirestore.instance
          .collection('servicios')
          .doc(servicioId)
          .update({'estado': 'cancelado'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Servicio cancelado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cancelar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelando.remove(servicioId));
    }
  }

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
            final estado = servicio['estado'];
            final cancelandoEste = _cancelando.contains(servicio.id);

            final sePuedeCancelar = estado == 'pendiente' ||
                estado == 'aceptado' ||
                estado == 'en camino';

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
                      "Estado: $estado",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: estado == 'cancelado' ? Colors.red : null,
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

                    if (estado == 'aceptado' ||
                        estado == 'en camino' ||
                        estado == 'trabajando')
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
                                  clienteLat:
                                      (servicio['lat'] as num).toDouble(),
                                  clienteLng:
                                      (servicio['lng'] as num).toDouble(),
                                  tipoServicio: servicio['tipoServicio'],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    if (estado == 'finalizado' &&
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

                    if (sePuedeCancelar) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          icon: cancelandoEste
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.red,
                                  ),
                                )
                              : const Icon(Icons.close),
                          label: const Text("Cancelar servicio"),
                          onPressed: cancelandoEste
                              ? null
                              : () => _confirmarCancelar(servicio.id),
                        ),
                      ),
                    ],

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