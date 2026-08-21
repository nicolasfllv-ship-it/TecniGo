import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tecnigo/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tecnigo/widgets/tecnico_drawer.dart';
import 'package:tecnigo/widgets/servicios_actuales_tecnico.dart';
import 'package:tecnigo/widgets/tecnico_header.dart';
import 'tecnico_mapa_screen.dart';

class HomeTecnicoScreen extends StatefulWidget {
  const HomeTecnicoScreen({super.key});

  @override
  State<HomeTecnicoScreen> createState() => _HomeTecnicoScreenState();
}

class _HomeTecnicoScreenState extends State<HomeTecnicoScreen> {
  StreamSubscription<Position>? _positionSub;

  // Guardamos la última posición conocida del técnico para poder calcular
  // qué tan lejos está cada solicitud pendiente.
  LatLng? _miPosicion;

  // Radio máximo (en km) para mostrarle una solicitud a este técnico.
  static const double _radioMaximoKm = 20;

  // Servicios que este técnico está en proceso de aceptar en este
  // momento (para no permitir doble toque en "Aceptar").
  final Set<String> _aceptando = {};

  @override
  void initState() {
    super.initState();
    _iniciarSeguimientoUbicacion();
  }

  @override
  void dispose() {
    // Muy importante: si no cancelamos esto, la app sigue pidiendo GPS
    // en segundo plano aunque el técnico haya salido de esta pantalla.
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _iniciarSeguimientoUbicacion() async {
    try {
      bool servicioActivo = await Geolocator.isLocationServiceEnabled();
      if (!servicioActivo) {
        _avisarErrorGPS(
          'Activa el GPS para poder recibir servicios cercanos.',
        );
        return;
      }

      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        _avisarErrorGPS(
          'Necesitamos tu ubicación para mostrarte servicios cercanos. '
          'Actívala desde Configuración.',
        );
        return;
      }

      // En vez de pedir la ubicación una sola vez, nos suscribimos a un
      // "stream" que nos avisa cada vez que el técnico se mueve al menos
      // 15 metros. Así el cliente lo ve moverse en el mapa en vivo.
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      );

      _positionSub =
          Geolocator.getPositionStream(locationSettings: settings)
              .listen((position) => _guardarUbicacion(position));

      // Y guardamos una primera posición de inmediato, sin esperar
      // a que el técnico se mueva 15 metros.
      final posicionInicial = await Geolocator.getCurrentPosition();
      await _guardarUbicacion(posicionInicial);
    } catch (e) {
      _avisarErrorGPS('No se pudo obtener tu ubicación: $e');
    }
  }

  void _avisarErrorGPS(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _aceptarServicio(String servicioId) async {
    if (_aceptando.contains(servicioId)) return;

    final tecnico = FirebaseAuth.instance.currentUser;
    if (tecnico == null) return;

    setState(() => _aceptando.add(servicioId));

    try {
      final docRef =
          FirebaseFirestore.instance.collection('servicios').doc(servicioId);

      // Usamos una transacción para que, si dos técnicos le dan
      // "Aceptar" casi al mismo tiempo, solo el primero gane: dentro
      // de la transacción volvemos a comprobar que el servicio siga
      // 'pendiente' antes de asignarlo.
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          throw Exception('Este servicio ya no existe');
        }

        if (snapshot.get('estado') != 'pendiente') {
          throw Exception('Otro técnico ya aceptó este servicio');
        }

        transaction.update(docRef, {
          'estado': 'aceptado',
          'tecnicoId': tecnico.uid,
          'tecnicoEmail': tecnico.email,
          'fechaAceptacion': Timestamp.now(),
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Servicio aceptado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _aceptando.remove(servicioId));
    }
  }

  Future<void> _guardarUbicacion(Position position) async {
    if (mounted) {
      setState(() {
        _miPosicion = LatLng(position.latitude, position.longitude);
      });
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'lat': position.latitude,
      'lng': position.longitude,
      'ubicacionActualizada': Timestamp.now(),
    });
  }

  Future<void> abrirMapa(double lat, double lng) async {
    final Uri url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );

    await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
  }

  // Íconos según el tipo de servicio, para que la lista se lea de un
  // vistazo en vez de tener que leer el texto completo cada vez.
  IconData _iconoServicio(String? tipo) {
    final t = (tipo ?? '').toLowerCase();
    if (t.contains('cámara') || t.contains('camara')) return Icons.videocam;
    if (t.contains('domótica') || t.contains('domotica')) return Icons.home_max;
    if (t.contains('acceso')) return Icons.fingerprint;
    if (t.contains('puerta') || t.contains('portón') || t.contains('porton')) {
      return Icons.garage;
    }
    if (t.contains('cerca')) return Icons.bolt;
    if (t.contains('cerraj')) return Icons.vpn_key;
    return Icons.build;
  }

  String _tiempoRelativo(dynamic fecha) {
    if (fecha is! Timestamp) return '';
    final diff = DateTime.now().difference(fecha.toDate());
    if (diff.inMinutes < 1) return 'Justo ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const TecnicoDrawer(),
      appBar: AppBar(
        title: const Text('TecniGo Técnico'),
      ),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: Column(
              children: [
                _SaludoTecnico(),
                TecnicoDisponibilidad(),
                ServiciosActualesTecnico(),
              ],
            ),
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid)
                .snapshots(),
            builder: (context, userSnap) {
              bool disponible = true;
              if (userSnap.hasData && userSnap.data!.exists) {
                final data = userSnap.data!.data() as Map<String, dynamic>;
                disponible = data['disponible'] ?? true;
              }

              if (!disponible) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: const _EstadoVacio(
                    icono: Icons.pause_circle_outline,
                    texto: 'Activa tu disponibilidad para ver los '
                        'servicios cercanos.',
                  ),
                );
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('servicios')
                    .where('estado', isEqualTo: 'pendiente')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      ),
                    );
                  }

                  final todosLosServicios = snapshot.data!.docs;

                  if (todosLosServicios.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EstadoVacio(
                        icono: Icons.inbox_outlined,
                        texto: 'No hay servicios pendientes por ahora.',
                      ),
                    );
                  }

                  // Si todavía no sabemos dónde está el técnico, no
                  // podemos calcular distancias todavía.
                  if (_miPosicion == null) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EstadoVacio(
                        icono: Icons.my_location,
                        texto: 'Obteniendo tu ubicación para mostrarte\n'
                            'los servicios más cercanos...',
                      ),
                    );
                  }

                  const Distance distanciaCalc = Distance();

                  // Calculamos qué tan lejos está cada solicitud del
                  // técnico, y nos quedamos solo con las que están
                  // dentro del radio permitido.
                  final serviciosConDistancia = todosLosServicios
                      .map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final posServicio = LatLng(
                          (data['lat'] as num).toDouble(),
                          (data['lng'] as num).toDouble(),
                        );
                        final km =
                            distanciaCalc(_miPosicion!, posServicio) / 1000;
                        return (doc: doc, km: km);
                      })
                      .where((item) => item.km <= _radioMaximoKm)
                      .toList()
                    ..sort((a, b) => a.km.compareTo(b.km));

                  if (serviciosConDistancia.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EstadoVacio(
                        icono: Icons.location_searching,
                        texto:
                            'No hay servicios cerca de ti en este momento.',
                      ),
                    );
                  }

                  return SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(18, 16, 18, 4),
                          child: Row(
                            children: [
                              const Text(
                                'Servicios cercanos',
                                style: TextStyle(
                                  color: AppColors.text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.accent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${serviciosConDistancia.length}',
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: 12),
                        sliver: SliverList.builder(
                          itemCount: serviciosConDistancia.length,
                          itemBuilder: (context, index) {
                            final servicio =
                                serviciosConDistancia[index].doc;
                            final distanciaKm =
                                serviciosConDistancia[index].km;
                            final data =
                                servicio.data() as Map<String, dynamic>;

                            return _TarjetaServicio(
                              icono: _iconoServicio(data['tipoServicio']),
                              tipoServicio: data['tipoServicio'] ?? '',
                              descripcion: data['descripcion'] ?? '',
                              emailCliente: data['emailCliente'] ?? '',
                              distanciaKm: distanciaKm,
                              tiempoRelativo:
                                  _tiempoRelativo(data['fecha']),
                              cargando: _aceptando.contains(servicio.id),
                              onVerRuta: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TecnicoMapaScreen(
                                      servicioId: servicio.id,
                                      tecnicoId: FirebaseAuth
                                          .instance.currentUser!.uid,
                                      clienteLat: (data['lat'] as num)
                                          .toDouble(),
                                      clienteLng: (data['lng'] as num)
                                          .toDouble(),
                                      tipoServicio: data['tipoServicio'],
                                    ),
                                  ),
                                );
                              },
                              onAceptar: () =>
                                  _aceptarServicio(servicio.id),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SaludoTecnico extends StatelessWidget {
  const _SaludoTecnico();

  String _saludoSegunHora() {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Buenos días';
    if (hora < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        String nombre = 'Técnico';
        bool disponible = true;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          if ((data['nombre'] ?? '').toString().isNotEmpty) {
            nombre = data['nombre'];
          }
          disponible = data['disponible'] ?? true;
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(14, 14, 14, 4),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                child: const Icon(Icons.engineering, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_saludoSegunHora()}, $nombre',
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      disponible
                          ? 'Estás recibiendo servicios cercanos'
                          : 'No estás recibiendo servicios ahora',
                      style: const TextStyle(
                        color: AppColors.subtitle,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (disponible ? AppColors.success : AppColors.subtitle)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: disponible
                            ? AppColors.success
                            : AppColors.subtitle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      disponible ? 'En línea' : 'Pausado',
                      style: TextStyle(
                        color: disponible
                            ? AppColors.success
                            : AppColors.subtitle,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _EstadoVacio({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: AppColors.subtitle, size: 48),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.subtitle),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaServicio extends StatelessWidget {
  final IconData icono;
  final String tipoServicio;
  final String descripcion;
  final String emailCliente;
  final double distanciaKm;
  final String tiempoRelativo;
  final bool cargando;
  final VoidCallback onVerRuta;
  final VoidCallback onAceptar;

  const _TarjetaServicio({
    required this.icono,
    required this.tipoServicio,
    required this.descripcion,
    required this.emailCliente,
    required this.distanciaKm,
    required this.tiempoRelativo,
    required this.cargando,
    required this.onVerRuta,
    required this.onAceptar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: Icon(icono, color: AppColors.primary),
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
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (tiempoRelativo.isNotEmpty)
                        Text(
                          tiempoRelativo,
                          style: const TextStyle(
                            color: AppColors.subtitle,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${distanciaKm.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (descripcion.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                descripcion,
                style: const TextStyle(color: AppColors.subtitle, fontSize: 14),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    color: AppColors.subtitle, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    emailCliente,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.subtitle, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onVerRuta,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Ver ruta'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: cargando ? null : onAceptar,
                    icon: cargando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.background,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Aceptar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}