import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'tecnico_mapa_screen.dart';

class MisServiciosTecnicoScreen extends StatefulWidget {
  final String? servicioIdFiltro;

  const MisServiciosTecnicoScreen({super.key, this.servicioIdFiltro});

  @override
  State<MisServiciosTecnicoScreen> createState() =>
      _MisServiciosTecnicoScreenState();
}

class _MisServiciosTecnicoScreenState
    extends State<MisServiciosTecnicoScreen> {
  // Guardamos los IDs de los servicios que están actualizándose en este
  // momento, para deshabilitar su botón y que no se pueda tocar dos veces.
  final Set<String> _actualizando = {};

  Future<void> _cambiarEstado(
    String servicioId,
    Map<String, dynamic> datos,
  ) async {
    if (_actualizando.contains(servicioId)) return;

    setState(() => _actualizando.add(servicioId));

    try {
      await FirebaseFirestore.instance
          .collection('servicios')
          .doc(servicioId)
          .update(datos);

      if (datos['estado'] == 'finalizado' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Servicio finalizado correctamente'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _actualizando.remove(servicioId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tecnico = FirebaseAuth.instance.currentUser;

    if (tecnico == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.servicioIdFiltro != null
              ? 'Servicio en curso'
              : 'Mis servicios asignados',
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('servicios')
            .where('tecnicoId', isEqualTo: tecnico.uid)
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

          var servicios = snapshot.data!.docs;

          if (widget.servicioIdFiltro != null) {
            servicios = servicios
                .where((doc) => doc.id == widget.servicioIdFiltro)
                .toList();
          }

          if (servicios.isEmpty) {
            return const Center(
              child: Text('No tienes servicios asignados'),
            );
          }

          return ListView.builder(
            itemCount: servicios.length,
            itemBuilder: (context, index) {
              final servicio = servicios[index];
              final estado = servicio['estado'];
              final actualizandoEste = _actualizando.contains(servicio.id);

              return Card(
                margin: const EdgeInsets.all(10),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        servicio['tipoServicio'],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        servicio['descripcion'],
                        style: const TextStyle(fontSize: 16),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        "Cliente: ${servicio['emailCliente']}",
                      ),

                      const SizedBox(height: 10),

                      Text(
                        "Estado: $estado",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 20),

                      if (estado == 'aceptado' ||
                          estado == 'en camino' ||
                          estado == 'trabajando')
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.map),
                            label: const Text('Ver ruta al cliente'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TecnicoMapaScreen(
                                    tecnicoId: tecnico.uid,
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

                      const SizedBox(height: 10),

                      if (estado == 'aceptado')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: actualizandoEste
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.directions_car),
                            label: const Text('En camino'),
                            onPressed: actualizandoEste
                                ? null
                                : () => _cambiarEstado(
                                      servicio.id,
                                      {'estado': 'en camino'},
                                    ),
                          ),
                        ),

                      if (estado == 'en camino')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: actualizandoEste
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.handyman),
                            label: const Text('Iniciar trabajo'),
                            onPressed: actualizandoEste
                                ? null
                                : () => _cambiarEstado(
                                      servicio.id,
                                      {'estado': 'trabajando'},
                                    ),
                          ),
                        ),

                      if (estado == 'trabajando')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: actualizandoEste
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check_circle),
                            label: const Text('Finalizar servicio'),
                            onPressed: actualizandoEste
                                ? null
                                : () => _cambiarEstado(
                                      servicio.id,
                                      {
                                        'estado': 'finalizado',
                                        'fechaFinalizacion': Timestamp.now(),
                                      },
                                    ),
                          ),
                        ),

                      if (estado == 'finalizado')
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Servicio finalizado",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
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
      ),
    );
  }
}