import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/eta_service.dart';
import '../theme/app_colors.dart';
import '../utils/servicio_duraciones.dart';
import '../widgets/scanner_frame.dart';

/// Pantalla que ve el CLIENTE: estilo tipo Yango/Uber — mapa grande
/// arriba y un panel abajo con toda la info del servicio y el técnico.
class SeguimientoScreen extends StatefulWidget {
  final String servicioId;
  final String tecnicoId;
  final double clienteLat;
  final double clienteLng;
  final String tipoServicio;

  const SeguimientoScreen({
    super.key,
    required this.servicioId,
    required this.tecnicoId,
    required this.clienteLat,
    required this.clienteLng,
    required this.tipoServicio,
  });

  @override
  State<SeguimientoScreen> createState() => _SeguimientoScreenState();
}

class _SeguimientoScreenState extends State<SeguimientoScreen> {
  final MapController _mapController = MapController();

  RutaInfo? _ruta;
  LatLng? _tecnicoPos;
  Timer? _debounceEta;
  bool _cancelando = false;

  late final LatLng _clientePos;

  @override
  void initState() {
    super.initState();
    _clientePos = LatLng(widget.clienteLat, widget.clienteLng);
  }

  @override
  void dispose() {
    _debounceEta?.cancel();
    super.dispose();
  }

  void _actualizarEtaConDebounce(LatLng nuevaPosTecnico) {
    _tecnicoPos = nuevaPosTecnico;
    _debounceEta?.cancel();
    _debounceEta = Timer(const Duration(seconds: 2), () async {
      final ruta = await EtaService.calcularRuta(
        origenTecnico: nuevaPosTecnico,
        destinoCliente: _clientePos,
      );
      if (mounted) setState(() => _ruta = ruta);
    });
  }

  String _textoEstado(String? estado) {
    switch (estado) {
      case 'aceptado':
        return 'El técnico va en camino';
      case 'en camino':
        return 'El técnico va en camino';
      case 'trabajando':
        return 'El técnico está trabajando';
      case 'finalizado':
        return 'Servicio finalizado';
      default:
        return 'Buscando técnico...';
    }
  }

  Future<void> _confirmarCancelar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar este servicio?'),
        content: const Text(
          'Esta acción no se puede deshacer. El servicio quedará '
          'cancelado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, mantenerlo'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sí, cancelar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _cancelando = true);

    try {
      await FirebaseFirestore.instance
          .collection('servicios')
          .doc(widget.servicioId)
          .update({'estado': 'cancelado'});

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Servicio cancelado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cancelar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duracionServicio =
        ServicioDuraciones.minutosEstimados(widget.tipoServicio);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento del técnico'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.tecnicoId)
            .snapshots(),
        builder: (context, tecnicoSnap) {
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('servicios')
                .doc(widget.servicioId)
                .snapshots(),
            builder: (context, servicioSnap) {
              final estado = servicioSnap.hasData && servicioSnap.data!.exists
                  ? (servicioSnap.data!.data()
                      as Map<String, dynamic>)['estado']
                  : null;

              String nombreTecnico = 'Técnico';
              LatLng? tecnicoPos;

              if (tecnicoSnap.hasData && tecnicoSnap.data!.exists) {
                final data =
                    tecnicoSnap.data!.data() as Map<String, dynamic>;
                if ((data['nombre'] ?? '').toString().isNotEmpty) {
                  nombreTecnico = data['nombre'];
                }
                if (data['lat'] != null && data['lng'] != null) {
                  tecnicoPos = LatLng(
                    (data['lat'] as num).toDouble(),
                    (data['lng'] as num).toDouble(),
                  );
                }
              }

              if (tecnicoPos != null &&
                  (_tecnicoPos == null ||
                      _tecnicoPos!.latitude != tecnicoPos.latitude ||
                      _tecnicoPos!.longitude != tecnicoPos.longitude)) {
                _actualizarEtaConDebounce(tecnicoPos);
              }

              final yaLlego = _ruta != null && _ruta!.distanciaKm <= 0.1;

              return Column(
                children: [
                  // ~62% de la pantalla: el mapa.
                  Expanded(
                    flex: 62,
                    child: tecnicoPos == null
                        ? const Center(
                            child: Text(
                              'Esperando ubicación del técnico...',
                            ),
                          )
                        : FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: tecnicoPos,
                              initialZoom: 14,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.tecnigo',
                              ),
                              if (_ruta != null &&
                                  _ruta!.puntosRuta.length > 1)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: _ruta!.puntosRuta,
                                      strokeWidth: 4,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: tecnicoPos,
                                    width: 54,
                                    height: 54,
                                    child: const ScannerFrame(
                                      tamano: 16,
                                      grosor: 2,
                                      child: Center(
                                        child: Icon(
                                          Icons.engineering,
                                          color: Colors.orange,
                                          size: 30,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Marker(
                                    point: _clientePos,
                                    width: 44,
                                    height: 44,
                                    child: const Icon(
                                      Icons.home,
                                      color: Colors.blue,
                                      size: 36,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),

                  // ~38% de la pantalla: el panel de información,
                  // estilo Yango/Uber.
                  Expanded(
                    flex: 38,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Barrita decorativa arriba del panel.
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppColors.border,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Estado grande, arriba de todo (lo primero
                            // que se lee, como en Yango).
                            Row(
                              children: [
                                Icon(
                                  yaLlego
                                      ? Icons.check_circle
                                      : Icons.directions_car,
                                  color: yaLlego
                                      ? AppColors.success
                                      : AppColors.primary,
                                  size: 28,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    yaLlego
                                        ? '¡Tu técnico ya llegó!'
                                        : _ruta == null
                                            ? 'Calculando llegada...'
                                            : '${_ruta!.minutosEstimados} min · '
                                                '${_ruta!.distanciaKm.toStringAsFixed(1)} km',
                                    style: TextStyle(
                                      color: yaLlego
                                          ? AppColors.success
                                          : AppColors.text,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            Text(
                              _textoEstado(estado),
                              style: const TextStyle(
                                color: AppColors.subtitle,
                                fontSize: 14,
                              ),
                            ),

                            const SizedBox(height: 18),
                            const Divider(color: AppColors.border),
                            const SizedBox(height: 14),

                            // Datos del técnico.
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppColors.background,
                                  child: Icon(Icons.engineering,
                                      color: AppColors.primary),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nombreTecnico,
                                        style: const TextStyle(
                                          color: AppColors.text,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.tipoServicio,
                                        style: const TextStyle(
                                          color: AppColors.subtitle,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.build,
                                      color: AppColors.subtitle, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'El servicio suele tardar unos '
                                      '$duracionServicio min',
                                      style: const TextStyle(
                                        color: AppColors.subtitle,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (estado == 'pendiente' ||
                                estado == 'aceptado' ||
                                estado == 'en camino') ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                  icon: _cancelando
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.red,
                                          ),
                                        )
                                      : const Icon(Icons.close),
                                  label: const Text('Cancelar servicio'),
                                  onPressed: _cancelando
                                      ? null
                                      : _confirmarCancelar,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}