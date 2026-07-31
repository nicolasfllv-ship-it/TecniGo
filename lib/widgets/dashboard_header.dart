import 'package:flutter/material.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "👋 Bienvenido a TecniGo",
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 10),

          Text(
            "Administra clientes, técnicos y servicios desde un solo lugar.",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),

          SizedBox(height: 10),

          Text(
            "(Panel en construcción — algunas funciones aún se están "
            "desarrollando)",
            style: TextStyle(
              color: Colors.white60,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}