import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tecnigo/screens/admin_usuario_detalle_screen.dart';
import 'package:tecnigo/theme/app_colors.dart';

class AdminTecnicosScreen extends StatefulWidget {
  const AdminTecnicosScreen({super.key});

  @override
  State<AdminTecnicosScreen> createState() => _AdminTecnicosScreenState();
}

class _AdminTecnicosScreenState extends State<AdminTecnicosScreen> {
  final TextEditingController _buscadorController = TextEditingController();
  String _busqueda = '';
  String _filtroDisponibilidad = 'todos';

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _serviciosSub;
  Map<String, _TecnicoMetricas> _metricasPorTecnico = {};

  @override
  void initState() {
    super.initState();
    _buscadorController.addListener(() {
      setState(() => _busqueda = _buscadorController.text.trim().toLowerCase());
    });

    _serviciosSub = FirebaseFirestore.instance
        .collection('servicios')
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;
          final map = <String, _TecnicoMetricas>{};
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final tecnicoId = data['tecnicoId'];
            if (tecnicoId == null || tecnicoId.toString().isEmpty) continue;
            final estado = (data['estado'] ?? '').toString();
            final m = map.putIfAbsent(
              tecnicoId.toString(),
              () => _TecnicoMetricas(),
            );
            if (estado == 'aceptado' ||
                estado == 'en camino' ||
                estado == 'trabajando') {
              m.activos++;
            } else if (estado == 'finalizado') {
              m.finalizados++;
            } else if (estado == 'cancelado') {
              m.cancelados++;
            }
          }
          setState(() => _metricasPorTecnico = map);
        });
  }

  @override
  void dispose() {
    _buscadorController.dispose();
    _serviciosSub?.cancel();
    super.dispose();
  }

  void _seleccionarFiltro(String filtro) {
    setState(() => _filtroDisponibilidad = filtro);
  }

  _MetricasGlobales _calcularMetricasGlobales(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final docs = snapshot.docs.where((doc) {
      final datos = doc.data();
      return (datos['rol'] ?? '').toString() == 'tecnico';
    }).toList();

    int total = docs.length;
    int disponibles = 0;
    int conUbicacion = 0;
    for (final doc in docs) {
      final datos = doc.data();
      if (datos['disponible'] == true) disponibles++;
      if (datos.containsKey('ubicacionActualizada') &&
          datos['ubicacionActualizada'] != null) {
        conUbicacion++;
      }
    }
    return _MetricasGlobales(
      total: total,
      disponibles: disponibles,
      noDisponibles: total - disponibles,
      conUbicacion: conUbicacion,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Técnicos')),
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
                        hintText: 'Buscar por nombre o correo',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        _FiltroDisponibilidad(
                          etiqueta: 'Todos',
                          valor: 'todos',
                          seleccionado: _filtroDisponibilidad,
                          onSelected: _seleccionarFiltro,
                        ),
                        _FiltroDisponibilidad(
                          etiqueta: 'Disponibles',
                          valor: 'disponibles',
                          seleccionado: _filtroDisponibilidad,
                          onSelected: _seleccionarFiltro,
                        ),
                        _FiltroDisponibilidad(
                          etiqueta: 'No disponibles',
                          valor: 'no_disponibles',
                          seleccionado: _filtroDisponibilidad,
                          onSelected: _seleccionarFiltro,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No se pudieron cargar los técnicos:\n${snapshot.error}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final metricasGlobales = _calcularMetricasGlobales(snapshot.data!);
                      final tecnicos = _filtrarTecnicos(snapshot.data!);

                      return Column(
                        children: [
                          _MetricasGlobalesWidget(metricas: metricasGlobales),
                          const SizedBox(height: 8),
                          Expanded(
                            child: tecnicos.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(
                                        _busqueda.isEmpty &&
                                                _filtroDisponibilidad == 'todos'
                                            ? 'No hay técnicos registrados.'
                                            : 'No se encontraron técnicos con esos filtros.',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: AppColors.subtitle,
                                        ),
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      16,
                                      16,
                                    ),
                                    itemCount: tecnicos.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) => _TecnicoCard(
                                      tecnico: tecnicos[index],
                                      metricas:
                                          _metricasPorTecnico[tecnicos[index].id] ??
                                              _TecnicoMetricas(),
                                    ),
                                  ),
                          ),
                        ],
                      );
                    },
                  )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtrarTecnicos(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final docs = snapshot.docs.where((doc) {
      final datos = doc.data();
      // Solo usuarios con rol exacto 'tecnico'.
      if ((datos['rol'] ?? '').toString() != 'tecnico') return false;

      final disponible = datos['disponible'] == true;
      final coincideDisponibilidad = switch (_filtroDisponibilidad) {
        'disponibles' => disponible,
        'no_disponibles' => !disponible,
        _ => true,
      };
      if (!coincideDisponibilidad) return false;

      if (_busqueda.isEmpty) return true;
      final nombre = (datos['nombre'] ?? '').toString().toLowerCase();
      final correo = (datos['email'] ?? '').toString().toLowerCase();
      return nombre.contains(_busqueda) || correo.contains(_busqueda);
    }).toList();

    // Orden alfabético por nombre.
    docs.sort((a, b) {
      final nombreA = (a.data()['nombre'] ?? '').toString();
      final nombreB = (b.data()['nombre'] ?? '').toString();
      return nombreA.toLowerCase().compareTo(nombreB.toLowerCase());
    });

    return docs;
  }
}
class _TecnicoCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> tecnico;
  final _TecnicoMetricas metricas;

  const _TecnicoCard({
    required this.tecnico,
    required this.metricas,
  });

  @override
  Widget build(BuildContext context) {
    final datos = tecnico.data();
    final foto = _fotoDesdeDatos(datos);
    final disponible = datos['disponible'] == true;
    final nombre = _textoORespaldo(datos['nombre'], 'Sin nombre');
    final correo = _textoORespaldo(datos['email'], 'Sin correo');

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.primary,
          backgroundImage: foto != null ? MemoryImage(foto) : null,
          child: foto == null
              ? const Icon(
                  Icons.person,
                  color: AppColors.background,
                  size: 28,
                )
              : null,
        ),
        title: Text(
          nombre,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Text(correo),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: disponible ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 6),
                Text(
                  disponible ? 'Disponible' : 'No disponible',
                  style: TextStyle(
                    color: disponible ? AppColors.success : AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (datos.containsKey('ubicacionActualizada')) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: AppColors.subtitle,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Ubicación: ${_fechaActualizada(datos['ubicacionActualizada'])}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.subtitle,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _MetricaChip(
                  etiqueta: 'Activos',
                  valor: metricas.activos,
                  color: AppColors.tecnicoAccent,
                ),
                _MetricaChip(
                  etiqueta: 'Finalizados',
                  valor: metricas.finalizados,
                  color: AppColors.success,
                ),
                _MetricaChip(
                  etiqueta: 'Cancelados',
                  valor: metricas.cancelados,
                  color: AppColors.error,
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminUsuarioDetalleScreen(usuarioId: tecnico.id),
            ),
          );
        },
      ),
    );
  }
}

class _MetricaChip extends StatelessWidget {
  final String etiqueta;
  final int valor;
  final Color color;

  const _MetricaChip({
    required this.etiqueta,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$etiqueta: ',
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            valor.toString(),
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
class _TecnicoMetricas {
  int activos = 0;
  int finalizados = 0;
  int cancelados = 0;
}

class _MetricasGlobales {
  final int total;
  final int disponibles;
  final int noDisponibles;
  final int conUbicacion;

  _MetricasGlobales({
    required this.total,
    required this.disponibles,
    required this.noDisponibles,
    required this.conUbicacion,
  });
}

class _ErrorCarga extends StatelessWidget {
  final String mensaje;

  const _ErrorCarga({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            mensaje,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _MetricasGlobalesWidget extends StatelessWidget {
  final _MetricasGlobales metricas;

  const _MetricasGlobalesWidget({required this.metricas});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _MetricaCard(
            titulo: 'Total',
            valor: metricas.total.toString(),
            icono: Icons.engineering,
            color: AppColors.primary,
          ),
          _MetricaCard(
            titulo: 'Disponibles',
            valor: metricas.disponibles.toString(),
            icono: Icons.check_circle,
            color: AppColors.success,
          ),
          _MetricaCard(
            titulo: 'No disponibles',
            valor: metricas.noDisponibles.toString(),
            icono: Icons.cancel,
            color: AppColors.error,
          ),
          _MetricaCard(
            titulo: 'Con ubicación',
            valor: metricas.conUbicacion.toString(),
            icono: Icons.location_on,
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

class _MetricaCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icono;
  final Color color;

  const _MetricaCard({
    required this.titulo,
    required this.valor,
    required this.icono,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icono, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.subtitle,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            valor,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltroDisponibilidad extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final String seleccionado;
  final ValueChanged<String> onSelected;

  const _FiltroDisponibilidad({
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

Uint8List? _fotoDesdeDatos(Map<String, dynamic> datos) {
  final fotoBase64 = (datos['fotoBase64'] ?? '').toString();
  if (fotoBase64.isEmpty) return null;

  try {
    return base64Decode(fotoBase64);
  } catch (_) {
    return null;
  }
}

String _textoORespaldo(dynamic valor, String respaldo) {
  final texto = (valor ?? '').toString().trim();
  return texto.isEmpty ? respaldo : texto;
}

String _fechaActualizada(dynamic valor) {
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
