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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       drawer: const TecnicoDrawer(),
       appBar: AppBar(
  title: const Text('TecniGo Técnico'),
),

      body: Column(
        children: [
          const TecnicoDisponibilidad(),
          const ServiciosActualesTecnico(),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .snapshots(),
              builder: (context, userSnap) {
                bool disponible = true;
                if (userSnap.hasData && userSnap.data!.exists) {
                  final data =
                      userSnap.data!.data() as Map<String, dynamic>;
                  disponible = data['disponible'] ?? true;
                }

                if (!disponible) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: Text(
                        'Activa tu disponibilidad para ver los '
                        'servicios cercanos.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(15, 20, 15, 5),
                      child: Row(
                        children: [
                          Text(
                            "Servicios cercanos",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('servicios')
                            .where('estado', isEqualTo: 'pendiente')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}'),
                            );
                          }

                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

          final todosLosServicios = snapshot.data!.docs;

          if (todosLosServicios.isEmpty) {
            return const Center(
              child: Text('No hay servicios pendientes'),
            );
          }

          // Si todavía no sabemos dónde está el técnico, no podemos
          // calcular distancias todavía.
          if (_miPosicion == null) {
            return const Center(
              child: Text('Obteniendo tu ubicación para mostrarte\n'
                  'los servicios más cercanos...',
                  textAlign: TextAlign.center),
            );
          }

          const Distance distanciaCalc = Distance();

          // Calculamos qué tan lejos está cada solicitud del técnico,
          // y nos quedamos solo con las que están dentro del radio
          // permitido (así un técnico en Bosa no ve ni puede aceptar
          // un servicio en Suba).
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
            return const Center(
              child: Text(
                'No hay servicios cerca de ti en este momento',
                textAlign: TextAlign.center,
              ),
            );
          }

          final servicios =
              serviciosConDistancia.map((item) => item.doc).toList();

          return ListView.builder(
            itemCount: servicios.length,
            itemBuilder: (context, index) {
              final servicio = servicios[index];
              final distanciaKm = serviciosConDistancia[index].km;

              return Card(
                margin: const EdgeInsets.all(12),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        servicio['tipoServicio'],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        servicio['descripcion'],
                        style: const TextStyle(fontSize: 16),
                      ),

                      const SizedBox(height: 15),

                      Text(
                        'Cliente: ${servicio['emailCliente']}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        '📍 A ${distanciaKm.toStringAsFixed(1)} km de ti',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TecnicoMapaScreen(
                                      servicioId: servicio.id,
                                      tecnicoId: FirebaseAuth
                                          .instance.currentUser!.uid,
                                      clienteLat:
                                          (servicio['lat'] as num)
                                              .toDouble(),
                                      clienteLng:
                                          (servicio['lng'] as num)
                                              .toDouble(),
                                      tipoServicio:
                                          servicio['tipoServicio'],
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.map),
                              label: const Text('Ver ruta'),
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _aceptando.contains(servicio.id)
                                  ? null
                                  : () => _aceptarServicio(servicio.id),
                              icon: _aceptando.contains(servicio.id)
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.background,
                                      ),
                                    )
                                  : const Icon(Icons.check),
                              label: const Text('Aceptar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
                    ),
                  ),
                ],
              );
              },
            ),
          ),
        ],
      ),
    );
  }
}