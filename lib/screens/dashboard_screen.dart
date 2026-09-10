import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tecnigo/screens/admin_reportes_screen.dart';
import 'package:tecnigo/screens/admin_servicios_screen.dart';
import 'package:tecnigo/screens/admin_tecnicos_screen.dart';
import 'package:tecnigo/screens/admin_usuarios_screen.dart';
import 'package:tecnigo/theme/app_colors.dart';
import 'package:tecnigo/widgets/admin_drawer.dart';
import 'package:tecnigo/widgets/dashboard_header.dart';
import 'package:tecnigo/widgets/dashboard_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int totalClientes = 0;
  int totalTecnicos = 0;
  int totalServicios = 0;
  int serviciosPendientes = 0;
  int serviciosAceptadosEnCamino = 0;
  int serviciosTrabajando = 0;
  int serviciosFinalizados = 0;
  int serviciosCancelados = 0;
  int serviciosReportados = 0;

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

      var pendientes = 0;
      var aceptadosEnCamino = 0;
      var trabajando = 0;
      var finalizados = 0;
      var cancelados = 0;
      var reportados = 0;

      for (final servicio in servicios.docs) {
        final datos = servicio.data() as Map<String, dynamic>;
        switch (datos['estado']) {
          case 'pendiente':
            pendientes++;
          case 'aceptado':
          case 'en camino':
            aceptadosEnCamino++;
          case 'trabajando':
            trabajando++;
          case 'finalizado':
            finalizados++;
          case 'cancelado':
            cancelados++;
        }
        if (datos['reportado'] == true) {
          reportados++;
        }
      }

      if (!mounted) return;
      setState(() {
        totalClientes = clientes.docs.length;
        totalTecnicos = tecnicos.docs.length;
        totalServicios = servicios.docs.length;
        serviciosPendientes = pendientes;
        serviciosAceptadosEnCamino = aceptadosEnCamino;
        serviciosTrabajando = trabajando;
        serviciosFinalizados = finalizados;
        serviciosCancelados = cancelados;
        serviciosReportados = reportados;
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(title: const Text('Panel de administrador')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const DashboardHeader(),
            const SizedBox(height: 25),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => GridView.count(
                  crossAxisCount: constraints.maxWidth >= 900 ? 3 : 2,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: constraints.maxWidth >= 900 ? 1.05 : 0.85,
                  children: [
                    DashboardCard(
                      titulo: 'Clientes',
                      valor: totalClientes.toString(),
                      icono: Icons.people,
                      color: AppColors.primary,
                      onTap: () => _abrir(context, const AdminUsuariosScreen()),
                    ),
                    DashboardCard(
                      titulo: 'Técnicos',
                      valor: totalTecnicos.toString(),
                      icono: Icons.engineering,
                      color: AppColors.accent,
                      onTap: () => _abrir(context, const AdminTecnicosScreen()),
                    ),
                    DashboardCard(
                      titulo: 'Servicios',
                      valor: totalServicios.toString(),
                      icono: Icons.build,
                      color: AppColors.success,
                      onTap: () =>
                          _abrir(context, const AdminServiciosScreen()),
                    ),
                    DashboardCard(
                      titulo: 'Pendientes',
                      valor: serviciosPendientes.toString(),
                      icono: Icons.schedule_outlined,
                      color: AppColors.accent,
                      onTap: () =>
                          _abrir(context, const AdminServiciosScreen()),
                    ),
                    DashboardCard(
                      titulo: 'Aceptados / en camino',
                      valor: serviciosAceptadosEnCamino.toString(),
                      icono: Icons.directions_car_outlined,
                      color: AppColors.clienteAccent,
                      onTap: () =>
                          _abrir(context, const AdminServiciosScreen()),
                    ),
                    DashboardCard(
                      titulo: 'Trabajando',
                      valor: serviciosTrabajando.toString(),
                      icono: Icons.handyman_outlined,
                      color: AppColors.tecnicoAccent,
                      onTap: () =>
                          _abrir(context, const AdminServiciosScreen()),
                    ),
                    DashboardCard(
                      titulo: 'Finalizados',
                      valor: serviciosFinalizados.toString(),
                      icono: Icons.check_circle_outline,
                      color: AppColors.success,
                      onTap: () =>
                          _abrir(context, const AdminServiciosScreen()),
                    ),
                    DashboardCard(
                      titulo: 'Cancelados',
                      valor: serviciosCancelados.toString(),
                      icono: Icons.cancel_outlined,
                      color: AppColors.error,
                      onTap: () =>
                          _abrir(context, const AdminServiciosScreen()),
                    ),
                    DashboardCard(
                      titulo: 'Reportados',
                      valor: serviciosReportados.toString(),
                      icono: Icons.report_problem_outlined,
                      color: AppColors.error,
                      onTap: () => _abrir(context, const AdminReportesScreen()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrir(BuildContext context, Widget pantalla) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
  }
}
