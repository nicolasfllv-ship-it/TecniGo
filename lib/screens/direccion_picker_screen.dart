import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tecnigo/theme/app_colors.dart';

/// Resultado que devuelve esta pantalla al confirmar la ubicación.
class UbicacionElegida {
  final double lat;
  final double lng;
  final String direccion;

  UbicacionElegida({
    required this.lat,
    required this.lng,
    required this.direccion,
  });
}

/// Sugerencia obtenida desde OpenStreetMap/Nominatim.
class _SugerenciaNominatim {
  final double lat;
  final double lng;
  final String nombre;
  final String direccionCompleta;

  _SugerenciaNominatim({
    required this.lat,
    required this.lng,
    required this.nombre,
    required this.direccionCompleta,
  });
}

/// Pantalla para elegir dónde va el servicio, al estilo Yango/DiDi:
/// un pin fijo en el centro de la pantalla y el mapa se arrastra por debajo.
///
/// La búsqueda de direcciones y el reverse geocoding utilizan
/// OpenStreetMap/Nominatim, sin depender de Google Places.
class DireccionPickerScreen extends StatefulWidget {
  const DireccionPickerScreen({super.key});

  @override
  State<DireccionPickerScreen> createState() => _DireccionPickerScreenState();
}

class _DireccionPickerScreenState extends State<DireccionPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _busquedaController =
      TextEditingController();
  final FocusNode _busquedaFocus = FocusNode();

  LatLng _centro = const LatLng(4.7110, -74.0721);
  String _direccionActual = 'Mueve el mapa para ubicar el sitio';

  LatLng? _miUbicacionGPS;
  String? _miDireccionGPS;

  List<_SugerenciaNominatim> _sugerencias = [];

  Timer? _debounceBusqueda;
  Timer? _debounceMapa;

  bool _cargandoUbicacionInicial = true;
  bool _cargandoDireccion = false;
  bool _buscando = false;

  int _idBusqueda = 0;

  /// Para no hacer demasiadas consultas seguidas a Nominatim.
  DateTime? _ultimaConsultaBusqueda;

  @override
  void initState() {
    super.initState();

    _busquedaFocus.addListener(_onFocoBusqueda);
    _obtenerUbicacionInicial();
  }

  @override
  void dispose() {
    _debounceBusqueda?.cancel();
    _debounceMapa?.cancel();

    _busquedaController.dispose();
    _busquedaFocus.dispose();

    super.dispose();
  }

  void _onFocoBusqueda() {
    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // UBICACIÓN GPS
  // ============================================================

  Future<void> _obtenerUbicacionInicial() async {
    try {
      final servicioActivo =
          await Geolocator.isLocationServiceEnabled();

      if (servicioActivo) {
        LocationPermission permiso =
            await Geolocator.checkPermission();

        if (permiso == LocationPermission.denied) {
          permiso = await Geolocator.requestPermission();
        }

        if (permiso != LocationPermission.denied &&
            permiso != LocationPermission.deniedForever) {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 8),
          );

          _centro = LatLng(pos.latitude, pos.longitude);
          _miUbicacionGPS = _centro;
        }
      }
    } catch (_) {
      // Si falla el GPS, usamos Bogotá como ubicación de respaldo.
    }

    if (!mounted) return;

    setState(() {
      _cargandoUbicacionInicial = false;
    });

    final direccion =
        await _consultarDireccionNominatim(_centro);

    if (!mounted) return;

    setState(() {
      _direccionActual = direccion;

      if (_miUbicacionGPS != null) {
        _miDireccionGPS = direccion;
      }
    });
  }

  // ============================================================
  // FORMATEAR DIRECCIÓN
  // ============================================================

  String _direccionCorta(Map<String, dynamic> data) {
    final addr =
        data['address'] as Map<String, dynamic>? ?? {};

    final calle =
        addr['road'] ??
        addr['pedestrian'] ??
        addr['residential'] ??
        addr['street'];

    final numero = addr['house_number'];

    final nombrePropio = data['name'] as String?;

    final barrio =
        addr['neighbourhood'] ??
        addr['suburb'] ??
        addr['quarter'] ??
        addr['hamlet'] ??
        addr['city_district'];

    final ciudad =
        addr['city'] ??
        addr['town'] ??
        addr['municipality'] ??
        addr['village'];

    final partes = <String>[];

    if (calle != null) {
      if (numero != null) {
        partes.add('$calle #$numero');
      } else {
        partes.add('$calle');
      }

      if (barrio != null) {
        partes.add('$barrio');
      }
    } else if (barrio != null) {
      partes.add('$barrio');
    } else if (nombrePropio != null &&
        nombrePropio.trim().isNotEmpty) {
      partes.add(nombrePropio);
    }

    if (ciudad != null &&
        ciudad.toString().trim().isNotEmpty &&
        !partes.contains(ciudad)) {
      partes.add('$ciudad');
    }

    String resultado;

    if (partes.isEmpty) {
      final display =
          (data['display_name'] ?? '').toString();

      final primero =
          display.split(',').first.trim();

      resultado =
          primero.isNotEmpty ? primero : display;
    } else {
      resultado = partes.join(', ');
    }

    resultado = resultado
        .replaceAll(
          RegExp(
            r'UPZs?\s*(de\s*Bogot[áa])?',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'Per[íi]metro\s*Urbano\s*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(r'\s*,\s*,\s*'),
          ', ',
        )
        .replaceAll(
          RegExp(r'^\s*,\s*|\s*,\s*$'),
          '',
        )
        .trim();

    if (resultado.isEmpty) {
      return (data['display_name'] ?? '').toString();
    }

    return resultado;
  }

  // ============================================================
  // REVERSE GEOCODING
  // COORDENADAS -> DIRECCIÓN
  // ============================================================

  Future<String> _consultarDireccionNominatim(
    LatLng punto,
  ) async {
    if (mounted) {
      setState(() {
        _cargandoDireccion = true;
      });
    }

    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/reverse',
        {
          'lat': punto.latitude.toString(),
          'lon': punto.longitude.toString(),
          'format': 'json',
          'addressdetails': '1',
          'accept-language': 'es',
        },
      );

      final respuesta = await http.get(
        uri,
        headers: {
          'User-Agent':
              'TecnosecurityApp/1.0 (contacto@tecnigo.app)',
          'Accept': 'application/json',
        },
      );

      if (respuesta.statusCode == 200) {
        final data = jsonDecode(respuesta.body);

        if (data is Map<String, dynamic>) {
          return _direccionCorta(data);
        }
      }
    } catch (_) {
      // Si falla, usamos las coordenadas.
    } finally {
      if (mounted) {
        setState(() {
          _cargandoDireccion = false;
        });
      }
    }

    return 'Lat: ${punto.latitude.toStringAsFixed(5)}, '
        'Lng: ${punto.longitude.toStringAsFixed(5)}';
  }

  // ============================================================
  // MOVER MAPA
  // ============================================================

  void _onMapaSeMovio(LatLng nuevoCentro) {
    _centro = nuevoCentro;

    _debounceMapa?.cancel();

    _debounceMapa =
        Timer(const Duration(milliseconds: 900), () async {
      final direccion =
          await _consultarDireccionNominatim(_centro);

      if (!mounted) return;

      setState(() {
        _direccionActual = direccion;
      });
    });
  }

  // ============================================================
  // BÚSQUEDA POR TEXTO
  // OPENSTREETMAP / NOMINATIM
  // ============================================================

  Future<void> _buscarDireccion(String query) async {
    final texto = query.trim();

    final idEstaBusqueda = ++_idBusqueda;

    if (texto.length < 3) {
      if (mounted) {
        setState(() {
          _sugerencias = [];
          _buscando = false;
        });
      }
      return;
    }

    // Evitamos consultas demasiado rápidas.
    final ahora = DateTime.now();

    if (_ultimaConsultaBusqueda != null) {
      final diferencia =
          ahora.difference(_ultimaConsultaBusqueda!);

      if (diferencia.inMilliseconds < 1100) {
        await Future.delayed(
          Duration(
            milliseconds:
                1100 - diferencia.inMilliseconds,
          ),
        );
      }
    }

    if (idEstaBusqueda != _idBusqueda) return;

    _ultimaConsultaBusqueda = DateTime.now();

    if (mounted) {
      setState(() {
        _buscando = true;
      });
    }

    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {
          'q': texto,
          'format': 'jsonv2',
          'addressdetails': '1',
          'limit': '6',
          'countrycodes': 'co',
          'accept-language': 'es',
        },
      );

      final respuesta = await http.get(
        uri,
        headers: {
          'User-Agent':
              'TecnosecurityApp/1.0 (contacto@tecnigo.app)',
          'Accept': 'application/json',
        },
      );

      if (idEstaBusqueda != _idBusqueda) return;

      if (respuesta.statusCode == 200) {
        final data = jsonDecode(respuesta.body);

        if (data is List) {
          final nuevas =
              <_SugerenciaNominatim>[];

          for (final item in data) {
            if (item is! Map<String, dynamic>) {
              continue;
            }

            final latString =
                item['lat']?.toString();

            final lngString =
                item['lon']?.toString();

            if (latString == null ||
                lngString == null) {
              continue;
            }

            final lat =
                double.tryParse(latString);

            final lng =
                double.tryParse(lngString);

            if (lat == null || lng == null) {
              continue;
            }

            final display =
                (item['display_name'] ?? '')
                    .toString();

            final direccion =
                _direccionCorta(item);

            final nombre =
                (item['name'] ?? '')
                    .toString()
                    .trim();

            String titulo;

            if (nombre.isNotEmpty) {
              titulo = nombre;
            } else if (direccion.isNotEmpty) {
              titulo = direccion
                  .split(',')
                  .first
                  .trim();
            } else {
              titulo = display
                  .split(',')
                  .first
                  .trim();
            }

            nuevas.add(
              _SugerenciaNominatim(
                lat: lat,
                lng: lng,
                nombre: titulo,
                direccionCompleta:
                    display.isNotEmpty
                        ? display
                        : direccion,
              ),
            );
          }

          if (mounted) {
            setState(() {
              _sugerencias = nuevas;
            });
          }
        }
      }
    } catch (e) {
      debugPrint(
        'Nominatim search error: $e',
      );
    } finally {
      if (mounted &&
          idEstaBusqueda == _idBusqueda) {
        setState(() {
          _buscando = false;
        });
      }
    }
  }

  // ============================================================
  // ELEGIR RESULTADO
  // ============================================================

  void _elegirSugerencia(
    _SugerenciaNominatim sugerencia,
  ) {
    final nuevoCentro = LatLng(
      sugerencia.lat,
      sugerencia.lng,
    );

    setState(() {
      _sugerencias = [];
      _busquedaController.clear();
      _busquedaFocus.unfocus();

      _centro = nuevoCentro;

      _direccionActual =
          _direccionBonitaDesdeSugerencia(
        sugerencia,
      );

      _cargandoDireccion = false;
    });

    _mapController.move(
      nuevoCentro,
      17,
    );
  }

  String _direccionBonitaDesdeSugerencia(
    _SugerenciaNominatim sugerencia,
  ) {
    final texto =
        sugerencia.direccionCompleta.trim();

    if (texto.isNotEmpty) {
      return texto;
    }

    return sugerencia.nombre;
  }

  // ============================================================
  // MI UBICACIÓN
  // ============================================================

  void _elegirMiUbicacion() {
    if (_miUbicacionGPS == null) return;

    setState(() {
      _centro = _miUbicacionGPS!;
      _direccionActual =
          _miDireccionGPS ?? _direccionActual;
    });

    _mapController.move(
      _miUbicacionGPS!,
      17,
    );

    _busquedaFocus.unfocus();
  }

  // ============================================================
  // CONFIRMAR
  // ============================================================

  void _confirmar() {
    Navigator.pop(
      context,
      UbicacionElegida(
        lat: _centro.latitude,
        lng: _centro.longitude,
        direccion: _direccionActual,
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final mostrarMiUbicacion =
        _busquedaFocus.hasFocus &&
        _busquedaController.text.trim().isEmpty &&
        _miUbicacionGPS != null;

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text(
          '¿Dónde es el servicio?',
        ),
      ),

      body: _cargandoUbicacionInicial
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.clienteAccent,
              ),
            )
          : GestureDetector(
              onTap: () {
                _busquedaFocus.unfocus();

                if (mounted) {
                  setState(() {});
                }
              },

              child: Stack(
                children: [
                  // =================================================
                  // MAPA
                  // =================================================

                  FlutterMap(
                    mapController:
                        _mapController,

                    options: MapOptions(
                      initialCenter: _centro,
                      initialZoom: 16,

                      onPositionChanged:
                          (posicion, hasGesto) {
                        if (hasGesto &&
                            posicion.center !=
                                null) {
                          _onMapaSeMovio(
                            posicion.center!,
                          );
                        }
                      },
                    ),

                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

                        userAgentPackageName:
                            'com.example.tecnigo',
                      ),
                    ],
                  ),

                  // =================================================
                  // PIN CENTRAL
                  // =================================================

                  const IgnorePointer(
                    child: Center(
                      child: Padding(
                        padding:
                            EdgeInsets.only(
                          bottom: 40,
                        ),

                        child: Icon(
                          Icons.location_on,
                          color:
                              AppColors.clienteAccent,
                          size: 48,
                        ),
                      ),
                    ),
                  ),

                  // =================================================
                  // BUSCADOR
                  // =================================================

                  Positioned(
                    top: 14,
                    left: 14,
                    right: 14,

                    child: Column(
                      children: [
                        Material(
                          color:
                              AppColors.surface,

                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),

                          elevation: 4,

                          child: TextField(
                            controller:
                                _busquedaController,

                            focusNode:
                                _busquedaFocus,

                            style:
                                const TextStyle(
                              color:
                                  AppColors.text,
                            ),

                            decoration:
                                InputDecoration(
                              hintText:
                                  'Busca tu dirección',

                              hintStyle:
                                  const TextStyle(
                                color:
                                    AppColors.subtitle,
                              ),

                              prefixIcon:
                                  const Icon(
                                Icons.search,
                                color:
                                    AppColors.subtitle,
                              ),

                              suffixIcon:
                                  _buscando
                                      ? const Padding(
                                          padding:
                                              EdgeInsets
                                                  .all(
                                            14,
                                          ),

                                          child:
                                              SizedBox(
                                            width: 16,
                                            height: 16,

                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth:
                                                  2,

                                              color:
                                                  AppColors
                                                      .clienteAccent,
                                            ),
                                          ),
                                        )
                                      : null,

                              border:
                                  OutlineInputBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  14,
                                ),

                                borderSide:
                                    BorderSide.none,
                              ),

                              filled: true,

                              fillColor:
                                  AppColors.surface,
                            ),

                            onChanged: (texto) {
                              setState(() {});

                              _debounceBusqueda
                                  ?.cancel();

                              _debounceBusqueda =
                                  Timer(
                                const Duration(
                                  milliseconds: 700,
                                ),
                                () {
                                  _buscarDireccion(
                                    texto,
                                  );
                                },
                              );
                            },
                          ),
                        ),

                        // =================================================
                        // MI UBICACIÓN
                        // =================================================

                        if (mostrarMiUbicacion)
                          Container(
                            margin:
                                const EdgeInsets
                                    .only(
                              top: 6,
                            ),

                            decoration:
                                BoxDecoration(
                              color:
                                  AppColors.surface,

                              borderRadius:
                                  BorderRadius
                                      .circular(
                                14,
                              ),

                              border: Border.all(
                                color:
                                    AppColors.border,
                              ),
                            ),

                            child: ListTile(
                              leading:
                                  const Icon(
                                Icons.my_location,
                                color: AppColors
                                    .clienteAccent,
                              ),

                              title:
                                  const Text(
                                'Usar mi ubicación actual',

                                style:
                                    TextStyle(
                                  color:
                                      AppColors.text,

                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),

                              subtitle:
                                  Text(
                                _miDireccionGPS ??
                                    '',

                                maxLines: 1,

                                overflow:
                                    TextOverflow
                                        .ellipsis,

                                style:
                                    const TextStyle(
                                  color: AppColors
                                      .subtitle,
                                ),
                              ),

                              onTap:
                                  _elegirMiUbicacion,
                            ),
                          ),

                        // =================================================
                        // RESULTADOS
                        // =================================================

                        if (_sugerencias
                            .isNotEmpty)
                          Container(
                            margin:
                                const EdgeInsets
                                    .only(
                              top: 6,
                            ),

                            decoration:
                                BoxDecoration(
                              color:
                                  AppColors.surface,

                              borderRadius:
                                  BorderRadius
                                      .circular(
                                14,
                              ),

                              border: Border.all(
                                color:
                                    AppColors.border,
                              ),
                            ),

                            child:
                                ListView.separated(
                              shrinkWrap: true,

                              physics:
                                  const NeverScrollableScrollPhysics(),

                              itemCount:
                                  _sugerencias
                                      .length,

                              separatorBuilder:
                                  (_, __) =>
                                      const Divider(
                                height: 1,
                                color:
                                    AppColors.border,
                              ),

                              itemBuilder:
                                  (context,
                                      index) {
                                final s =
                                    _sugerencias[
                                        index];

                                return ListTile(
                                  leading:
                                      const Icon(
                                    Icons
                                        .location_on_outlined,
                                    color: AppColors
                                        .clienteAccent,
                                  ),

                                  title:
                                      Text(
                                    s.nombre,

                                    maxLines: 1,

                                    overflow:
                                        TextOverflow
                                            .ellipsis,

                                    style:
                                        const TextStyle(
                                      color:
                                          AppColors
                                              .text,

                                      fontWeight:
                                          FontWeight
                                              .w600,
                                    ),
                                  ),

                                  subtitle:
                                      Text(
                                    s.direccionCompleta,

                                    maxLines: 2,

                                    overflow:
                                        TextOverflow
                                            .ellipsis,

                                    style:
                                        const TextStyle(
                                      color: AppColors
                                          .subtitle,
                                    ),
                                  ),

                                  onTap: () =>
                                      _elegirSugerencia(
                                    s,
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),

                  // =================================================
                  // BOTÓN MI UBICACIÓN
                  // =================================================

                  Positioned(
                    right: 14,
                    bottom: 150,

                    child:
                        FloatingActionButton.small(
                      heroTag:
                          'mi_ubicacion_picker',

                      backgroundColor:
                          AppColors.surface,

                      foregroundColor:
                          AppColors.clienteAccent,

                      onPressed:
                          _miUbicacionGPS == null
                              ? null
                              : _elegirMiUbicacion,

                      child:
                          const Icon(
                        Icons.my_location,
                      ),
                    ),
                  ),

                  // =================================================
                  // PANEL INFERIOR
                  // =================================================

                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,

                    child: Container(
                      padding:
                          const EdgeInsets
                              .fromLTRB(
                        18,
                        16,
                        18,
                        24,
                      ),

                      decoration:
                          const BoxDecoration(
                        color:
                            AppColors.surface,

                        borderRadius:
                            BorderRadius
                                .vertical(
                          top: Radius.circular(
                            20,
                          ),
                        ),
                      ),

                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,

                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.place,
                                color: AppColors
                                    .clienteAccent,
                                size: 20,
                              ),

                              const SizedBox(
                                width: 8,
                              ),

                              Expanded(
                                child:
                                    _cargandoDireccion
                                        ? const Text(
                                            'Ubicando dirección...',

                                            style:
                                                TextStyle(
                                              color:
                                                  AppColors
                                                      .subtitle,
                                            ),
                                          )
                                        : Text(
                                            _direccionActual,

                                            maxLines: 2,

                                            overflow:
                                                TextOverflow
                                                    .ellipsis,

                                            style:
                                                const TextStyle(
                                              color:
                                                  AppColors
                                                      .text,

                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                            ),
                                          ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 16,
                          ),

                          SizedBox(
                            width:
                                double.infinity,

                            height: 52,

                            child:
                                ElevatedButton(
                              style:
                                  ElevatedButton
                                      .styleFrom(
                                backgroundColor:
                                    AppColors
                                        .clienteAccent,

                                foregroundColor:
                                    Colors.white,
                              ),

                              onPressed:
                                  _cargandoDireccion
                                      ? null
                                      : _confirmar,

                              child:
                                  const Text(
                                'Confirmar ubicación',
                              ),
                            ),
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
}