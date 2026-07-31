import 'package:flutter/material.dart';

class DashboardCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icono;
  final Color color;

  const DashboardCard({
    super.key,
    required this.titulo,
    required this.valor,
    required this.icono,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shadowColor: color.withOpacity(0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            CircleAvatar(
              radius: 32,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(
                icono,
                color: color,
                size: 34,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              valor,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              titulo,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.black54,
              ),
            ),

          ],
        ),
      ),
    );
  }
}