import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tecnigo/widgets/dashboard_widgets.dart';
import 'package:tecnigo/widgets/dashboard_header.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int totalClientes = 0;
  int totalTecnicos = 0;
  int totalServicios = 0;

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    try {
      final clientes = await FirebaseFirestore.instance
          .collection('users')
          .where('rol', isEqualTo: 'cliente')
          .get();

      final tecnicos = await FirebaseFirestore.instance
          .collection('users')
          .where('rol', isEqualTo: 'tecnico')
          .get();

      final servicios = await FirebaseFirestore.instance
          .collection('servicios')
          .get();

      setState(() {
        totalClientes = clientes.docs.length;
        totalTecnicos = tecnicos.docs.length;
        totalServicios = servicios.docs.length;
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("TecniGo Dashboard"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const DashboardHeader(),
            const SizedBox(height: 25),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 0.85,
                children: [
                  DashboardCard(
                    titulo: "Clientes",
                    valor: totalClientes.toString(),
                    icono: Icons.people,
                    color: Colors.blue,
                  ),
                  DashboardCard(
                    titulo: "Técnicos",
                    valor: totalTecnicos.toString(),
                    icono: Icons.engineering,
                    color: Colors.green,
                  ),
                  DashboardCard(
                    titulo: "Servicios",
                    valor: totalServicios.toString(),
                    icono: Icons.build,
                    color: Colors.orange,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}