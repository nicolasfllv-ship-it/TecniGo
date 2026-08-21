import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tecnigo/theme/app_colors.dart';
import 'package:tecnigo/screens/mis_servicios_tecnico_screen.dart';
import 'package:tecnigo/screens/tecnico_mapa_screen.dart';

/// Resumen, en el Home del técnico, de los servicios que ya tiene
/// asignados y están en curso (aceptado / en camino / trabajando).
/// Si es solo uno, muestra una tarjeta con los datos del cliente, el
/// estado actual, y un botón para avanzar directo al siguiente paso
/// (sin tener que entrar a otra pantalla). Si son varios, una fila
/// simple con el total.
class ServiciosActualesTecnico extends StatefulWidget {
  const ServiciosActualesTecnico({super.key});

  @override
  State<ServiciosActualesTecnico> createState() =>
      _ServiciosActualesTecnicoState();
}

class _ServiciosActualesTecnicoState extends State<ServiciosActualesTecnico> {
  bool _actualizando = false;

  Future<void> _cambiarEstado(String servicioId, Map<String, dynamic> datos) async {
    if (_actualizando) return;
    setState(() => _actualizando = true);

    try {
      await FirebaseFirestore.instance
          .collection('servicios')
          .doc(servicioId)
          .update(datos);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _actualizando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('servicios')
          .where('tecnicoId', isEqualTo: user.uid)
          .where('estado', whereIn: ['aceptado', 'en camino', 'trabajando'])
          .snapshots(),
      builder: (context, snapshot) {
        final servicios = snapshot.data?.docs ?? [];

        if (servicios.isEmpty) {
          return const SizedBox.shrink();
        }

        if (servicios.length > 1) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(15),
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MisServiciosTecnicoScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.assignment_turned_in,
                          color: AppColors.tecnicoAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tienes ${servicios.length} servicios en curso',
                          style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppColors.subtitle),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final doc = servicios.first;
        final data = doc.data() as Map<String, dynamic>;
        final estado = data['estado'] as String;
        final clienteId = data['clienteId'] as String?;
        final emailCliente = (data['emailCliente'] ?? 'Cliente').toString();
        final tipoServicio = (data['tipoServicio'] ?? '').toString();

        return Padding(
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
          child: StreamBuilder<DocumentSnapshot>(
            stream: clienteId == null
                ? const Stream.empty()
                : FirebaseFirestore.instance
                    .collection('users')
                    .doc(clienteId)
                    .snapshots(),
            builder: (context, clienteSnap) {
              String nombreCliente = emailCliente;
              Uint8List? fotoBytes;

              if (clienteSnap.hasData && clienteSnap.data!.exists) {
                final cdata =
                    clienteSnap.data!.data() as Map<String, dynamic>;
                if ((cdata['nombre'] ?? '').toString().isNotEmpty) {
                  nombreCliente = cdata['nombre'];
                }
                if ((cdata['fotoBase64'] ?? '').toString().isNotEmpty) {
                  try {
                    fotoBytes = base64Decode(cdata['fotoBase64']);
                  } catch (_) {}
                }
              }

              final String badgeTexto;
              final IconData badgeIcono;
              switch (estado) {
                case 'aceptado':
                  badgeTexto = 'Asignado';
                  badgeIcono = Icons.assignment_turned_in;
                  break;
                case 'en camino':
                  badgeTexto = 'En camino';
                  badgeIcono = Icons.directions_car;
                  break;
                default:
                  badgeTexto = 'Trabajando';
                  badgeIcono = Icons.handyman;
              }

              return Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Servicio en curso',
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.tecnicoAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(badgeIcono,
                                  color: AppColors.tecnicoAccent, size: 14),
                              const SizedBox(width: 5),
                              Text(
                                badgeTexto,
                                style: const TextStyle(
                                  color: AppColors.tecnicoAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              AppColors.tecnicoAccent.withOpacity(0.15),
                          backgroundImage:
                              fotoBytes != null ? MemoryImage(fotoBytes) : null,
                          child: fotoBytes == null
                              ? const Icon(Icons.person,
                                  color: AppColors.tecnicoAccent)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombreCliente,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                tipoServicio,
                                style: const TextStyle(
                                  color: AppColors.subtitle,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.tecnicoAccent,
                              side: const BorderSide(
                                  color: AppColors.tecnicoAccent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TecnicoMapaScreen(
                                    servicioId: doc.id,
                                    tecnicoId: user.uid,
                                    clienteLat:
                                        (data['lat'] as num).toDouble(),
                                    clienteLng:
                                        (data['lng'] as num).toDouble(),
                                    tipoServicio: tipoServicio,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.map_outlined, size: 18),
                            label: const Text('Ver mapa'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.tecnicoAccent,
                              foregroundColor: AppColors.background,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _actualizando
                                ? null
                                : () {
                                    if (estado == 'aceptado') {
                                      _cambiarEstado(
                                          doc.id, {'estado': 'en camino'});
                                    } else if (estado == 'en camino') {
                                      _cambiarEstado(
                                          doc.id, {'estado': 'trabajando'});
                                    } else {
                                      _cambiarEstado(doc.id, {
                                        'estado': 'finalizado',
                                        'fechaFinalizacion': Timestamp.now(),
                                      });
                                    }
                                  },
                            icon: _actualizando
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.background,
                                    ),
                                  )
                                : Icon(
                                    estado == 'trabajando'
                                        ? Icons.check_circle
                                        : Icons.arrow_forward,
                                    size: 18,
                                  ),
                            label: Text(
                              estado == 'aceptado'
                                  ? 'En camino'
                                  : estado == 'en camino'
                                      ? 'Iniciar trabajo'
                                      : 'Finalizar',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}