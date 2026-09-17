import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tecnigo/screens/admin_reporte_detalle_screen.dart';
import 'package:tecnigo/theme/app_colors.dart';

class AdminReportesScreen extends StatefulWidget {
  const AdminReportesScreen({super.key});

  @override
  State<AdminReportesScreen> createState() => _AdminReportesScreenState();
}

class _AdminReportesScreenState extends State<AdminReportesScreen> {
  final TextEditingController _buscadorController = TextEditingController();
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _buscadorController.addListener(() {
      setState(() => _busqueda = _buscadorController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _buscadorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final anchoMaximo = constraints.maxWidth >= 900
              ? 840.0
              : double.infinity;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: anchoMaximo),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      controller: _buscadorController,
                      style: const TextStyle(color: AppColors.text),
                      decoration: const InputDecoration(
                        hintText:
                            'Buscar por ID, cliente, técnico, tipo o motivo',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('servicios')
                          .where('reportado', isEqualTo: true)
                          .orderBy('fechaReporte', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No se pudieron cargar los reportes:\n${snapshot.error}',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final reportes = _filtrarReportes(snapshot.data!);

                        if (reportes.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _busqueda.isEmpty
                                    ? 'No hay servicios reportados.'
                                    : 'No se encontraron reportes con esa búsqueda.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.subtitle,
                                ),
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: reportes.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) =>
                              _ReporteCard(reporte: reportes[index]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtrarReportes(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (_busqueda.isEmpty) return snapshot.docs;

    final docs = snapshot.docs.where((doc) {
      final datos = doc.data();

      final id = doc.id.toLowerCase();
      final tipoServicio = (datos['tipoServicio'] ?? '')
          .toString()
          .toLowerCase();
      final emailCliente = (datos['emailCliente'] ?? '')
          .toString()
          .toLowerCase();
      final tecnicoEmail = (datos['tecnicoEmail'] ?? '')
          .toString()
          .toLowerCase();
      final motivoReporte = (datos['motivoReporte'] ?? '')
          .toString()
          .toLowerCase();

      return id.contains(_busqueda) ||
          tipoServicio.contains(_busqueda) ||
          emailCliente.contains(_busqueda) ||
          tecnicoEmail.contains(_busqueda) ||
          motivoReporte.contains(_busqueda);
    }).toList();

    return docs;
  }
}

class _ReporteCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> reporte;

  const _ReporteCard({required this.reporte});

  @override
  Widget build(BuildContext context) {
    final datos = reporte.data();
    final id = reporte.id;
    final tipoServicio = (datos['tipoServicio'] ?? '').toString();
    final motivoReporte = (datos['motivoReporte'] ?? '').toString();
    final fechaReporte = datos['fechaReporte'];
    final emailCliente = (datos['emailCliente'] ?? '').toString();
    final tecnicoEmail = (datos['tecnicoEmail'] ?? '').toString();
    final estado = (datos['estado'] ?? '').toString();

    final Color estadoColor = _colorEstado(estado);

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminReporteDetalleScreen(servicioId: reporte.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tipoServicio.isEmpty ? 'Sin tipo' : tipoServicio,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${_truncarId(id)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.subtitle,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: estadoColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: estadoColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      _estadoLegible(estado),
                      style: TextStyle(
                        color: estadoColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (motivoReporte.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.report_problem_outlined,
                      size: 16,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        motivoReporte,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.text,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ] else ...[
                Row(
                  children: [
                    const Icon(
                      Icons.report_problem_outlined,
                      size: 16,
                      color: AppColors.subtitle,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Sin motivo especificado',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.subtitle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 16,
                    color: AppColors.subtitle,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Cliente: ${emailCliente.isEmpty ? 'Sin email' : emailCliente}',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.engineering_outlined,
                    size: 16,
                    color: AppColors.subtitle,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Técnico: ${tecnicoEmail.isEmpty ? 'Sin asignar' : tecnicoEmail}',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: AppColors.subtitle,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Reporte: ${_fechaLegible(fechaReporte)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.subtitle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return AppColors.accent;
      case 'aceptado':
        return AppColors.clienteAccent;
      case 'en camino':
        return AppColors.clienteAccent;
      case 'trabajando':
        return AppColors.tecnicoAccent;
      case 'finalizado':
        return AppColors.success;
      case 'cancelado':
        return AppColors.error;
      default:
        return AppColors.subtitle;
    }
  }

  String _estadoLegible(String estado) {
    switch (estado) {
      case 'pendiente':
        return 'Pendiente';
      case 'aceptado':
        return 'Aceptado';
      case 'en camino':
        return 'En camino';
      case 'trabajando':
        return 'Trabajando';
      case 'finalizado':
        return 'Finalizado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return estado.isEmpty ? 'Desconocido' : estado;
    }
  }

  String _truncarId(String id) {
    if (id.length <= 12) return id;
    return '${id.substring(0, 8)}...${id.substring(id.length - 4)}';
  }

  String _fechaLegible(dynamic valor) {
    DateTime? fecha;
    if (valor is Timestamp) {
      fecha = valor.toDate();
    } else if (valor is DateTime) {
      fecha = valor;
    }

    if (fecha == null) {
      return valor == null ? 'No disponible' : valor.toString();
    }

    String dosDigitos(int numero) => numero.toString().padLeft(2, '0');
    return '${dosDigitos(fecha.day)}/${dosDigitos(fecha.month)}/${fecha.year} '
        '${dosDigitos(fecha.hour)}:${dosDigitos(fecha.minute)}';
  }
}
