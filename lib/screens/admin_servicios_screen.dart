import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tecnigo/screens/admin_servicio_detalle_screen.dart';
import 'package:tecnigo/theme/app_colors.dart';

class AdminServiciosScreen extends StatefulWidget {
  final String? filtroInicial;

  const AdminServiciosScreen({super.key, this.filtroInicial});

  @override
  State<AdminServiciosScreen> createState() => _AdminServiciosScreenState();
}

class _AdminServiciosScreenState extends State<AdminServiciosScreen> {
  final TextEditingController _buscadorController = TextEditingController();
  String _busqueda = '';
  String _filtroEstado = 'todos';

  @override
  void initState() {
    super.initState();
    if (widget.filtroInicial != null) {
      _filtroEstado = widget.filtroInicial!;
    }
    _buscadorController.addListener(() {
      setState(() => _busqueda = _buscadorController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _buscadorController.dispose();
    super.dispose();
  }

  void _seleccionarFiltro(String filtro) {
    setState(() => _filtroEstado = filtro);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Servicios')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final anchoMaximo =
              constraints.maxWidth >= 900 ? 840.0 : double.infinity;
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
                        hintText: 'Buscar por ID, cliente, técnico, tipo o dirección',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FiltroEstado(
                          etiqueta: 'Todos',
                          valor: 'todos',
                          seleccionado: _filtroEstado,
                          onSelected: _seleccionarFiltro,
                        ),
                        _FiltroEstado(
                          etiqueta: 'Pendiente',
                          valor: 'pendiente',
                          seleccionado: _filtroEstado,
                          onSelected: _seleccionarFiltro,
                        ),
                        _FiltroEstado(
                          etiqueta: 'Aceptado',
                          valor: 'aceptado',
                          seleccionado: _filtroEstado,
                          onSelected: _seleccionarFiltro,
                        ),
                        _FiltroEstado(
                          etiqueta: 'En camino',
                          valor: 'en camino',
                          seleccionado: _filtroEstado,
                          onSelected: _seleccionarFiltro,
                        ),
                        _FiltroEstado(
                          etiqueta: 'Trabajando',
                          valor: 'trabajando',
                          seleccionado: _filtroEstado,
                          onSelected: _seleccionarFiltro,
                        ),
                        _FiltroEstado(
                          etiqueta: 'Finalizado',
                          valor: 'finalizado',
                          seleccionado: _filtroEstado,
                          onSelected: _seleccionarFiltro,
                        ),
                        _FiltroEstado(
                          etiqueta: 'Cancelado',
                          valor: 'cancelado',
                          seleccionado: _filtroEstado,
                          onSelected: _seleccionarFiltro,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('servicios')
                          .orderBy('fecha', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No se pudieron cargar los servicios:\n${snapshot.error}',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final servicios = _filtrarServicios(snapshot.data!);

                        if (servicios.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _busqueda.isEmpty && _filtroEstado == 'todos'
                                    ? 'No hay servicios registrados.'
                                    : 'No se encontraron servicios con esos filtros.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.subtitle),
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: servicios.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) =>
                              _ServicioCard(servicio: servicios[index]),
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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtrarServicios(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final docs = snapshot.docs.where((doc) {
      final datos = doc.data();

      final estado = (datos['estado'] ?? '').toString();
      bool coincideEstado;
      if (_filtroEstado == 'todos') {
        coincideEstado = true;
      } else if (_filtroEstado == 'aceptados_en_camino') {
        coincideEstado = estado == 'aceptado' || estado == 'en camino';
      } else {
        coincideEstado = estado == _filtroEstado;
      }

      if (!coincideEstado) return false;

      if (_busqueda.isEmpty) return true;

      final id = doc.id.toLowerCase();
      final tipoServicio = (datos['tipoServicio'] ?? '').toString().toLowerCase();
      final emailCliente = (datos['emailCliente'] ?? '').toString().toLowerCase();
      final tecnicoEmail = (datos['tecnicoEmail'] ?? '').toString().toLowerCase();
      final direccion = (datos['direccion'] ?? '').toString().toLowerCase();

      return id.contains(_busqueda) ||
          tipoServicio.contains(_busqueda) ||
          emailCliente.contains(_busqueda) ||
          tecnicoEmail.contains(_busqueda) ||
          direccion.contains(_busqueda);
    }).toList();

    return docs;
  }
}

class _ServicioCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> servicio;

  const _ServicioCard({required this.servicio});

  @override
  Widget build(BuildContext context) {
    final datos = servicio.data();
    final id = servicio.id;
    final tipoServicio = (datos['tipoServicio'] ?? '').toString();
    final emailCliente = (datos['emailCliente'] ?? '').toString();
    final tecnicoEmail = (datos['tecnicoEmail'] ?? '').toString();
    final estado = (datos['estado'] ?? '').toString();
    final direccion = (datos['direccion'] ?? '').toString();
    final fecha = datos['fecha'];

    final Color estadoColor = _colorEstado(estado);

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminServicioDetalleScreen(servicioId: id),
            ),
          );
        },
        borderRadius: BorderRadius.zero,
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            if (direccion.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AppColors.subtitle),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      direccion,
                      style: const TextStyle(fontSize: 13, color: AppColors.text),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: AppColors.subtitle),
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
                const Icon(Icons.engineering_outlined, size: 16, color: AppColors.subtitle),
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
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.subtitle),
                const SizedBox(width: 6),
                Text(
                  'Fecha: ${_fechaLegible(fecha)}',
                  style: const TextStyle(fontSize: 13, color: AppColors.subtitle),
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

class _FiltroEstado extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final String seleccionado;
  final ValueChanged<String> onSelected;

  const _FiltroEstado({
    required this.etiqueta,
    required this.valor,
    required this.seleccionado,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(etiqueta),
      selected: seleccionado == valor,
      onSelected: (_) => onSelected(valor),
    );
  }
}