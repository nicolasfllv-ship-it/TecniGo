import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/eta_service.dart';
import '../theme/app_colors.dart';

/// Pantalla que ve el TÉCNICO: muestra en un mapa, dentro de la misma
/// app, la ruta desde su ubicación actual hasta la del cliente, con
/// distancia y tiempo estimado. También deja abrir Google Maps por
/// fuera, por si el técnico prefiere navegación real paso a paso.
class TecnicoMapaScreen extends StatefulWidget {
  final String tecnicoId;
  final double clienteLat;
  final double clienteLng;
  final String tipoServicio;

  const TecnicoMapaScreen({
    super.key,
    required this.tecnicoId,
    required this.clienteLat,
    required this.clienteLng,
    required this.tipoServicio,
  });

  @override
  State<TecnicoMapaScreen> createState() => _TecnicoMapaScreenState();
}

class _TecnicoMapaScreenState extends State<TecnicoMapaScreen> {
  final MapController _mapController = MapController();

  RutaInfo? _ruta;
  LatLng? _miPosAnterior;
  Timer? _debounceEta;

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

  void _actualizarEtaConDebounce(LatLng miPos) {
    _miPosAnterior = miPos;
    _debounceEta?.cancel();
    _debounceEta = Timer(const Duration(seconds: 2), () async {
      final ruta = await EtaService.calcularRuta(
        origenTecnico: miPos,
        destinoCliente: _clientePos,
      );
      if (mounted) setState(() => _ruta = ruta);
    });
  }

  Future<void> _abrirGoogleMaps() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination='
      '${widget.clienteLat},${widget.clienteLng}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruta al cliente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Abrir en Google Maps',
            onPressed: _abrirGoogleMaps,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.tecnicoId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          if (data['lat'] == null || data['lng'] == null) {
            return const Center(
              child: Text('Obteniendo tu ubicación...'),
            );
          }

          final miPos = LatLng(
            (data['lat'] as num).toDouble(),
            (data['lng'] as num).toDouble(),
          );

          if (_miPosAnterior == null ||
              _miPosAnterior!.latitude != miPos.latitude ||
              _miPosAnterior!.longitude != miPos.longitude) {
            _actualizarEtaConDebounce(miPos);
          }

          return Column(
            children: [
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: miPos,
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.tecnigo',
                    ),
                    if (_ruta != null && _ruta!.puntosRuta.length > 1)
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
                          point: miPos,
                          width: 44,
                          height: 44,
                          child: const Icon(
                            Icons.engineering,
                            color: Colors.orange,
                            size: 36,
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_car,
                        color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _ruta == null
                            ? 'Calculando ruta...'
                            : '${_ruta!.minutosEstimados} min '
                                '(${_ruta!.distanciaKm.toStringAsFixed(1)} km) '
                                'hasta el cliente',
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}