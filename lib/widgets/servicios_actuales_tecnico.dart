import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tecnigo/theme/app_colors.dart';
import 'package:tecnigo/screens/mis_servicios_tecnico_screen.dart';

/// Resumen, en el Home del técnico, de los servicios que ya tiene
/// asignados y están en curso (aceptado / en camino / trabajando).
/// Estos NO aparecen en la lista de "pendientes" de abajo, porque esa
/// lista solo muestra los que todavía nadie ha aceptado.
class ServiciosActualesTecnico extends StatelessWidget {
  const ServiciosActualesTecnico({super.key});

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
                    builder: (_) => MisServiciosTecnicoScreen(
                      servicioIdFiltro:
                          servicios.length == 1 ? servicios.first.id : null,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.assignment_turned_in,
                        color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        servicios.length == 1
                            ? 'Tienes 1 servicio en curso'
                            : 'Tienes ${servicios.length} servicios en curso',
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
      },
    );
  }
}