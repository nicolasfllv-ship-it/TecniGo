import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:tecnigo/theme/app_colors.dart';
import 'package:tecnigo/services/eta_service.dart';
import 'package:tecnigo/screens/seguimiento_screen.dart';

/// Muestra el servicio que el cliente tiene activo en este momento.
/// - Sin servicios: mensaje simple.
/// - "pendiente" (sin técnico todavía): fila simple, "Buscando técnico...".
/// - Con técnico asignado: tarjeta grande con mini-mapa real, foto y
///   nombre del técnico, y tiempo estimado de llegada.
class ServicioActualCard extends StatelessWidget {
  const ServicioActualCard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('servicios')
          .where('clienteId', isEqualTo: user.uid)
          .where('estado', whereIn: ['pendiente', 'aceptado', 'en camino', 'trabajando'])
          .snapshots(),
      builder: (context, snapshot) {
        final servicios = snapshot.data?.docs ?? [];

        if (servicios.isEmpty) {
          return _TarjetaBase(
            child: const Text(
              'No tienes servicios activos.',
              style: TextStyle(color: AppColors.subtitle, fontSize: 16),
            ),
          );
        }

        final doc = servicios.first;
        final data = doc.data() as Map<String, dynamic>;
        final estado = data['estado'];
        final tipoServicio = (data['tipoServicio'] ?? '').toString();
        final tecnicoId = data['tecnicoId'] as String?;
        final lat = data['lat'];
        final lng = data['lng'];
        final datosCompletos = tecnicoId != null && lat != null && lng != null;

        if (estado == 'pendiente' || !datosCompletos) {
          return _TarjetaBase(
            child: Row(
              children: [
                const Icon(
                  Icons.hourglass_top,
                  color: AppColors.subtitle,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tipoServicio,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        estado == 'pendiente'
                            ? 'Buscando técnico...'
                            : 'Faltan datos de este servicio',
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
          );
        }

        return _ServicioEnProgresoCard(
          servicioId: doc.id,
          tecnicoId: tecnicoId!,
          clienteLat: (lat as num).toDouble(),
          clienteLng: (lng as num).toDouble(),
          tipoServicio: tipoServicio,
          estado: estado,
        );
      },
    );
  }
}

class _TarjetaBase extends StatelessWidget {
  final Widget child;

  const _TarjetaBase({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Servicio actual',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ServicioEnProgresoCard extends StatefulWidget {
  final String servicioId;
  final String tecnicoId;
  final double clienteLat;
  final double clienteLng;
  final String tipoServicio;
  final String estado;

  const _ServicioEnProgresoCard({
    required this.servicioId,
    required this.tecnicoId,
    required this.clienteLat,
    required this.clienteLng,
    required this.tipoServicio,
    required this.estado,
  });

  @override
  State<_ServicioEnProgresoCard> createState() =>
      _ServicioEnProgresoCardState();
}

class _ServicioEnProgresoCardState extends State<_ServicioEnProgresoCard> {
  RutaInfo? _ruta;
  LatLng? _tecnicoPosAnterior;
  Timer? _debounce;

  late final LatLng _clientePos =
      LatLng(widget.clienteLat, widget.clienteLng);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _actualizarRutaConDebounce(LatLng tecnicoPos) {
    _tecnicoPosAnterior = tecnicoPos;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () async {
      final ruta = await EtaService.calcularRuta(
        origenTecnico: tecnicoPos,
        destinoCliente: _clientePos,
      );
      if (mounted) setState(() => _ruta = ruta);
    });
  }

  void _abrirSeguimiento() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SeguimientoScreen(
          servicioId: widget.servicioId,
          tecnicoId: widget.tecnicoId,
          clienteLat: widget.clienteLat,
          clienteLng: widget.clienteLng,
          tipoServicio: widget.tipoServicio,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.tecnicoId)
          .snapshots(),
      builder: (context, snapshot) {
        String nombreTecnico = 'Técnico';
        Uint8List? fotoBytes;
        LatLng? tecnicoPos;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          if ((data['nombre'] ?? '').toString().isNotEmpty) {
            nombreTecnico = data['nombre'];
          }
          if ((data['fotoBase64'] ?? '').toString().isNotEmpty) {
            try {
              fotoBytes = base64Decode(data['fotoBase64']);
            } catch (_) {}
          }
          if (data['lat'] != null && data['lng'] != null) {
            tecnicoPos = LatLng(
              (data['lat'] as num).toDouble(),
              (data['lng'] as num).toDouble(),
            );
          }
        }

        if (tecnicoPos != null &&
            (_tecnicoPosAnterior == null ||
                _tecnicoPosAnterior!.latitude != tecnicoPos.latitude ||
                _tecnicoPosAnterior!.longitude != tecnicoPos.longitude)) {
          _actualizarRutaConDebounce(tecnicoPos);
        }

        final textoEstado = widget.estado == 'trabajando'
            ? 'Técnico trabajando'
            : 'Técnico en camino';

        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _abrirSeguimiento,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Servicio en progreso',
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.clienteAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.estado == 'trabajando'
                              ? 'En sitio'
                              : 'En camino',
                          style: const TextStyle(
                            color: AppColors.clienteAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor:
                            AppColors.clienteAccent.withOpacity(0.15),
                        backgroundImage:
                            fotoBytes != null ? MemoryImage(fotoBytes) : null,
                        child: fotoBytes == null
                            ? const Icon(Icons.engineering,
                                color: AppColors.clienteAccent)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombreTecnico,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              textoEstado,
                              style: const TextStyle(
                                color: AppColors.subtitle,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_ruta != null)
                        Text(
                          '${_ruta!.minutosEstimados} min',
                          style: const TextStyle(
                            color: AppColors.clienteAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Mini-mapa: solo vista previa, sin gestos (para que no
                // pelee con el scroll del home). Tocar la tarjeta entera
                // abre el mapa completo interactivo.
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(20)),
                  child: SizedBox(
                    height: 140,
                    child: tecnicoPos == null
                        ? Container(color: AppColors.background)
                        : IgnorePointer(
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: tecnicoPos,
                                initialZoom: 14,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.none,
                                ),
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
                                        color: AppColors.clienteAccent,
                                      ),
                                    ],
                                  ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: tecnicoPos,
                                      width: 30,
                                      height: 30,
                                      child: const Icon(
                                        Icons.engineering,
                                        color: Colors.orange,
                                        size: 24,
                                      ),
                                    ),
                                    Marker(
                                      point: _clientePos,
                                      width: 26,
                                      height: 26,
                                      child: const Icon(
                                        Icons.home,
                                        color: AppColors.clienteAccent,
                                        size: 22,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}