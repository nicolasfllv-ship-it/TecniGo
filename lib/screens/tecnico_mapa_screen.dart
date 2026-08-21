import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/eta_service.dart';
import '../theme/app_colors.dart';
import 'chat_screen.dart';

/// Pantalla que ve el TÉCNICO: muestra en un mapa, dentro de la misma
/// app, la ruta desde su ubicación actual hasta la del cliente, con
/// distancia y tiempo estimado. También deja abrir Google Maps por
/// fuera, y avanzar el estado del servicio (en camino / trabajando /
/// finalizado) directo desde aquí.
class TecnicoMapaScreen extends StatefulWidget {
  final String servicioId;
  final String tecnicoId;
  final double clienteLat;
  final double clienteLng;
  final String tipoServicio;

  const TecnicoMapaScreen({
    super.key,
    required this.servicioId,
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
  static const Distance _distanciaCalc = Distance();

  // Qué tan cerca (en metros) tiene que estar el técnico del cliente
  // para poder marcar "Iniciar trabajo" — evita que lo marque estando
  // en otro lado.
  static const double _radioLlegadaMetros = 100;

  RutaInfo? _ruta;
  LatLng? _miPosAnterior;
  Timer? _debounceEta;
  bool _liberando = false;
  bool _abriendoChat = false;
  bool _actualizandoEstado = false;

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

  Future<void> _abrirChat() async {
    setState(() => _abriendoChat = true);
    try {
      final servicioDoc = await FirebaseFirestore.instance
          .collection('servicios')
          .doc(widget.servicioId)
          .get();

      final data = servicioDoc.data();
      final clienteId = data?['clienteId'] as String?;

      if (clienteId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No se encontró el cliente de este servicio')),
          );
        }
        return;
      }

      String nombreCliente = (data?['emailCliente'] ?? 'Cliente').toString();

      final clienteDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(clienteId)
          .get();

      if (clienteDoc.exists) {
        final clienteData = clienteDoc.data() as Map<String, dynamic>;
        if ((clienteData['nombre'] ?? '').toString().isNotEmpty) {
          nombreCliente = clienteData['nombre'];
        }
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            servicioId: widget.servicioId,
            miUid: widget.tecnicoId,
            miRol: 'tecnico',
            nombreOtro: nombreCliente,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el chat: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _abriendoChat = false);
    }
  }

  Future<void> _cambiarEstado(
    Map<String, dynamic> datos, {
    bool cerrarAlTerminar = false,
  }) async {
    if (_actualizandoEstado) return;
    setState(() => _actualizandoEstado = true);

    try {
      await FirebaseFirestore.instance
          .collection('servicios')
          .doc(widget.servicioId)
          .update(datos);

      if (mounted && datos['estado'] == 'finalizado') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Servicio finalizado correctamente')),
        );
      }

      if (mounted && cerrarAlTerminar) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _actualizandoEstado = false);
    }
  }

  void _intentarIniciarTrabajo(LatLng miPos) {
    final distanciaMetros = _distanciaCalc(miPos, _clientePos);

    if (distanciaMetros > _radioLlegadaMetros) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Debes estar cerca del cliente para iniciar el trabajo '
            '(estás a ${distanciaMetros.toStringAsFixed(0)} m).',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    _cambiarEstado({'estado': 'trabajando'});
  }

  Future<void> _confirmarLiberar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Liberar este servicio?'),
        content: const Text(
          'El servicio volverá a quedar disponible para que otro '
          'técnico lo pueda aceptar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sí, liberar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _liberando = true);

    try {
      await FirebaseFirestore.instance
          .collection('servicios')
          .doc(widget.servicioId)
          .update({
        'estado': 'pendiente',
        'tecnicoId': FieldValue.delete(),
        'tecnicoEmail': FieldValue.delete(),
        'fechaAceptacion': FieldValue.delete(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Servicio liberado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al liberar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _liberando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruta al cliente'),
        actions: [
          IconButton(
            icon: _abriendoChat
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chat_bubble_outline),
            tooltip: 'Chat con el cliente',
            onPressed: _abriendoChat ? null : _abrirChat,
          ),
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

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('servicios')
                .doc(widget.servicioId)
                .snapshots(),
            builder: (context, servicioSnap) {
              final estado = servicioSnap.hasData && servicioSnap.data!.exists
                  ? (servicioSnap.data!.data()
                      as Map<String, dynamic>)['estado']
                  : 'aceptado';

              final distanciaMetros = _distanciaCalc(miPos, _clientePos);
              final cercaDelCliente = distanciaMetros <= _radioLlegadaMetros;

              return Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        FlutterMap(
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
                                    strokeWidth: 5,
                                    color: AppColors.tecnicoAccent,
                                  ),
                                ],
                              ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: miPos,
                                  width: 40,
                                  height: 40,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.surface,
                                      border: Border.all(
                                        color: AppColors.tecnicoAccent,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.engineering,
                                      color: Colors.orange,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                Marker(
                                  point: _clientePos,
                                  width: 34,
                                  height: 34,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.background,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.home,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Botón "recentrar", como en Waze: vuelve a
                        // centrar el mapa en tu propia posición si te
                        // alejaste.
                        Positioned(
                          right: 14,
                          bottom: 14,
                          child: FloatingActionButton.small(
                            heroTag: 'recentrar_tecnico',
                            backgroundColor: AppColors.surface,
                            foregroundColor: AppColors.tecnicoAccent,
                            onPressed: () {
                              _mapController.move(miPos, 15);
                            },
                            child: const Icon(Icons.my_location),
                          ),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.directions_car,
                                color: AppColors.tecnicoAccent),
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

                        if (estado == 'en camino') ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                cercaDelCliente
                                    ? Icons.check_circle
                                    : Icons.info_outline,
                                size: 16,
                                color: cercaDelCliente
                                    ? AppColors.success
                                    : AppColors.subtitle,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  cercaDelCliente
                                      ? 'Ya estás cerca del cliente'
                                      : 'Debes estar a menos de '
                                          '${_radioLlegadaMetros.toStringAsFixed(0)} m '
                                          'para iniciar el trabajo',
                                  style: const TextStyle(
                                    color: AppColors.subtitle,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 14),

                        if (estado == 'aceptado')
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.tecnicoAccent,
                                foregroundColor: AppColors.background,
                              ),
                              icon: _actualizandoEstado
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.background,
                                      ),
                                    )
                                  : const Icon(Icons.directions_car),
                              label: const Text('En camino'),
                              onPressed: _actualizandoEstado
                                  ? null
                                  : () => _cambiarEstado(
                                      {'estado': 'en camino'}),
                            ),
                          ),

                        if (estado == 'en camino')
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cercaDelCliente
                                    ? AppColors.tecnicoAccent
                                    : AppColors.border,
                                foregroundColor: cercaDelCliente
                                    ? AppColors.background
                                    : AppColors.subtitle,
                              ),
                              icon: _actualizandoEstado
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.background,
                                      ),
                                    )
                                  : const Icon(Icons.handyman),
                              label: const Text('Iniciar trabajo'),
                              onPressed: _actualizandoEstado
                                  ? null
                                  : () => _intentarIniciarTrabajo(miPos),
                            ),
                          ),

                        if (estado == 'trabajando')
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: AppColors.background,
                              ),
                              icon: _actualizandoEstado
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.background,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle),
                              label: const Text('Finalizar servicio'),
                              onPressed: _actualizandoEstado
                                  ? null
                                  : () => _cambiarEstado(
                                        {
                                          'estado': 'finalizado',
                                          'fechaFinalizacion':
                                              Timestamp.now(),
                                        },
                                        cerrarAlTerminar: true,
                                      ),
                            ),
                          ),

                        if (estado == 'aceptado' || estado == 'en camino') ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                              icon: _liberando
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.red,
                                      ),
                                    )
                                  : const Icon(Icons.close),
                              label: const Text('Liberar servicio'),
                              onPressed:
                                  _liberando ? null : _confirmarLiberar,
                            ),
                          ),
                        ],
                      ],
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