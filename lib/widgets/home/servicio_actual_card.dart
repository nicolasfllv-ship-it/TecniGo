import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tecnigo/theme/app_colors.dart';
import 'package:tecnigo/screens/seguimiento_screen.dart';

/// Ahora sí conectado a Firestore: muestra el servicio que el cliente
/// tiene activo en este momento (pendiente o ya aceptado por un técnico).
/// Si no tiene ninguno, muestra el mensaje de "no tienes servicios activos".
class ServicioActualCard extends StatelessWidget {
  const ServicioActualCard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('servicios')
          .where('clienteId', isEqualTo: user.uid)
          .where('estado', whereIn: ['pendiente', 'aceptado', 'en camino', 'trabajando'])
          .snapshots(),
      builder: (context, snapshot) {
        final servicios = snapshot.data?.docs ?? [];

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Servicio actual",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              if (servicios.isEmpty)
                const Text(
                  "No tienes servicios activos.",
                  style: TextStyle(
                    color: AppColors.subtitle,
                    fontSize: 16,
                  ),
                )
              else
                ...servicios.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final estado = data['estado'];
                  final tipoServicio = data['tipoServicio'] ?? '';

                  // El campo tecnicoId, la lat y la lng del cliente son
                  // obligatorios para poder abrir el mapa de seguimiento.
                  // Si algún servicio de prueba quedó sin alguno de estos
                  // datos, lo tratamos como "no navegable" en vez de
                  // reventar la app.
                  final tecnicoId = data['tecnicoId'] as String?;
                  final lat = data['lat'];
                  final lng = data['lng'];
                  final datosCompletos =
                      tecnicoId != null && lat != null && lng != null;

                  final activo = datosCompletos &&
                      (estado == 'aceptado' ||
                          estado == 'en camino' ||
                          estado == 'trabajando');

                  final textoEstado = estado == 'pendiente'
                      ? "Buscando técnico..."
                      : !datosCompletos
                          ? "Faltan datos de este servicio"
                          : estado == 'trabajando'
                              ? "Técnico trabajando"
                              : "Técnico en camino";

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: !activo
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SeguimientoScreen(
                                      servicioId: doc.id,
                                      tecnicoId: tecnicoId!,
                                      clienteLat: (lat as num).toDouble(),
                                      clienteLng: (lng as num).toDouble(),
                                      tipoServicio: tipoServicio,
                                    ),
                                  ),
                                );
                              },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Icon(
                                estado == 'pendiente'
                                    ? Icons.hourglass_top
                                    : Icons.directions_car,
                                color: estado == 'pendiente'
                                    ? AppColors.subtitle
                                    : AppColors.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tipoServicio,
                                      style: const TextStyle(
                                        color: AppColors.text,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      textoEstado,
                                      style: const TextStyle(
                                        color: AppColors.subtitle,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (activo)
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.subtitle,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}