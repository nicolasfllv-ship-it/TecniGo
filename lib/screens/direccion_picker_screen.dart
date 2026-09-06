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

class _SugerenciaGoogle {
  final String placeId;
  final String textoPrincipal;
  final String textoSecundario;

  _SugerenciaGoogle({
    required this.placeId,
    required this.textoPrincipal,
    required this.textoSecundario,
  });
}

/// Pantalla para elegir dónde va el servicio, al estilo Yango/DiDi:
/// un pin fijo en el centro de la pantalla, y el mapa se arrastra por
/// debajo para ajustarlo.
///
/// La búsqueda de direcciones por texto usa Google Places API (New),
/// porque el buscador gratuito (OpenStreetMap/Nominatim) no tiene
/// bien mapeadas las direcciones con número de casa en Colombia.
/// El ajuste fino arrastrando el mapa sigue usando el buscador
/// gratuito, para mantener el costo lo más bajo posible.
class DireccionPickerScreen extends StatefulWidget {
  const DireccionPickerScreen({super.key});

  @override
  State<DireccionPickerScreen> createState() => _DireccionPickerScreenState();
}

class _DireccionPickerScreenState extends State<DireccionPickerScreen> {
  // TODO: por seguridad, en un proyecto real esta llave no debería
  // quedar escrita directo en el código fuente (lo ideal es pasarla
  // con --dart-define al compilar). Para esta etapa del proyecto,
  // así es suficiente.
  static const String _googleApiKey =
      'AIzaSyBjWT_rtzKse1U3MAOORRsQq_84PKH1km4';

  final MapController _mapController = MapController();
  final TextEditingController _busquedaController = TextEditingController();
  final FocusNode _busquedaFocus = FocusNode();

  LatLng _centro = const LatLng(4.7110, -74.0721); // Bogotá, de respaldo
  String _direccionActual = 'Mueve el mapa para ubicar el sitio';

  // Guardamos aparte la ubicación GPS real (no la del pin, que puede
  // moverse), para poder ofrecerla como "mi ubicación actual".
  LatLng? _miUbicacionGPS;
  String? _miDireccionGPS;

  List<_SugerenciaGoogle> _sugerencias = [];
  Timer? _debounceBusqueda;
  bool _cargandoUbicacionInicial = true;
  bool _cargandoDireccion = false;
  bool _buscando = false;
  int _idBusqueda = 0;

  // El "session token" agrupa las pulsaciones de autocompletado con la
  // consulta final de detalles, para que Google las cobre como una
  // sola sesión en vez de por separado. Se renueva cada vez que se
  // elige una sugerencia o se abre la pantalla.
  String _sessionToken = '';

  @override
  void initState() {
    super.initState();
    _sessionToken = _generarSessionToken();
    _busquedaFocus.addListener(_onFocoBusqueda);
    _obtenerUbicacionInicial();
  }

  @override
  void dispose() {
    _debounceBusqueda?.cancel();
    _busquedaController.dispose();
    _busquedaFocus.dispose();
    super.dispose();
  }

  String _generarSessionToken() {
    final random = Random();
    return List.generate(32, (_) => random.nextInt(16).toRadixString(16))
        .join();
  }

  void _onFocoBusqueda() {
    if (_busquedaFocus.hasFocus && _busquedaController.text.trim().isEmpty) {
      setState(() {});
    }
  }

  Future<void> _obtenerUbicacionInicial() async {
    try {
      final servicioActivo = await Geolocator.isLocationServiceEnabled();
      if (servicioActivo) {
        final permiso = await Geolocator.checkPermission();
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
      // Si falla, nos quedamos con el punto de respaldo (Bogotá).
    }

    if (mounted) {
      setState(() => _cargandoUbicacionInicial = false);
      final direccion = await _consultarDireccionNominatim(_centro);
      if (mounted) {
        setState(() {
          _direccionActual = direccion;
          if (_miUbicacionGPS != null) {
            _miDireccionGPS = direccion;
          }
        });
      }
    }
  }

  // ---------- Reverse geocoding (gratuito) para el arrastre del mapa ----------

  String _direccionCorta(Map<String, dynamic> data) {
    final addr = data['address'] as Map<String, dynamic>? ?? {};

    final calle = addr['road'] ?? addr['pedestrian'] ?? addr['residential'];
    final numero = addr['house_number'];
    final nombrePropio = data['name'] as String?;

    final barrio = addr['neighbourhood'] ??
        addr['suburb'] ??
        addr['quarter'] ??
        addr['hamlet'] ??
        addr['city_district'];

    final ciudad = addr['city'] ??
        addr['town'] ??
        addr['municipality'] ??
        addr['village'];

    final partes = <String>[];

    if (calle != null) {
      partes.add(numero != null ? '$calle #$numero' : '$calle');
      if (barrio != null) partes.add('$barrio');
    } else if (barrio != null) {
      partes.add('$barrio');
    } else if (nombrePropio != null) {
      partes.add(nombrePropio);
    }

    if (ciudad != null && !partes.contains(ciudad)) {
      partes.add('$ciudad');
    }

    String resultado;
    if (partes.isEmpty) {
      final display = (data['display_name'] ?? '').toString();
      final primero = display.split(',').first.trim();
      resultado = primero.isNotEmpty ? primero : display;
    } else {
      resultado = partes.join(', ');
    }

    resultado = resultado
        .replaceAll(RegExp(r'UPZs?\s*(de\s*Bogot[áa])?', caseSensitive: false),
            '')
        .replaceAll(
            RegExp(r'Per[íi]metro\s*Urbano\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*,\s*,\s*'), ', ')
        .replaceAll(RegExp(r'^\s*,\s*|\s*,\s*$'), '')
        .trim();

    return resultado.isEmpty ? (data['display_name'] ?? '').toString() : resultado;
  }

  Future<String> _consultarDireccionNominatim(LatLng punto) async {
    setState(() => _cargandoDireccion = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${punto.latitude}&lon=${punto.longitude}'
        '&format=json&addressdetails=1',
      );
      final respuesta = await http.get(
        uri,
        headers: {'User-Agent': 'TecniGoApp/1.0'},
      );

      if (respuesta.statusCode == 200) {
        final data = jsonDecode(respuesta.body);
        return _direccionCorta(data);
      }
    } catch (_) {
      // Sigue abajo con el respaldo de coordenadas.
    } finally {
      if (mounted) setState(() => _cargandoDireccion = false);
    }

    return 'Lat: ${punto.latitude.toStringAsFixed(5)}, '
        'Lng: ${punto.longitude.toStringAsFixed(5)}';
  }

  void _onMapaSeMovio(LatLng nuevoCentro) {
    _centro = nuevoCentro;
    _debounceBusqueda?.cancel();
    _debounceBusqueda = Timer(const Duration(milliseconds: 700), () async {
      final direccion = await _consultarDireccionNominatim(_centro);
      if (mounted) setState(() => _direccionActual = direccion);
    });
  }

  // ---------- Búsqueda por texto (Google Places, con costo mínimo) ----------

  Future<void> _buscarDireccion(String query) async {
    final idEstaBusqueda = ++_idBusqueda;

    if (query.trim().length < 2) {
      if (mounted) setState(() => _sugerencias = []);
      return;
    }

    setState(() => _buscando = true);

    try {
      final uri =
          Uri.parse('https://places.googleapis.com/v1/places:autocomplete');

      final respuesta = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _googleApiKey,
        },
        body: jsonEncode({
          'input': query,
          'includedRegionCodes': ['co'],
          'languageCode': 'es',
          'sessionToken': _sessionToken,
        }),
      );

      if (idEstaBusqueda != _idBusqueda) return;

      debugPrint('Google Places status: ${respuesta.statusCode}');
      debugPrint('Google Places body: ${respuesta.body}');

      if (respuesta.statusCode == 200) {
        final data = jsonDecode(respuesta.body);
        final List sugerenciasRaw = data['suggestions'] ?? [];

        final nuevas = sugerenciasRaw
            .map((s) {
              final prediccion = s['placePrediction'];
              if (prediccion == null) return null;

              final formato = prediccion['structuredFormat'];
              final principal = formato?['mainText']?['text'] ??
                  prediccion['text']?['text'] ??
                  '';
              final secundario = formato?['secondaryText']?['text'] ?? '';

              return _SugerenciaGoogle(
                placeId: prediccion['placeId'] ?? '',
                textoPrincipal: principal,
                textoSecundario: secundario,
              );
            })
            .whereType<_SugerenciaGoogle>()
            .where((s) => s.placeId.isNotEmpty)
            .toList();

        if (mounted) setState(() => _sugerencias = nuevas);
      }
      // Si falla, dejamos la última lista válida en vez de vaciarla.
    } catch (e) {
      debugPrint('Google Places error: $e');
      // Igual: si falla la conexión, no borramos lo que ya se veía.
    } finally {
      if (mounted && idEstaBusqueda == _idBusqueda) {
        setState(() => _buscando = false);
      }
    }
  }

  Future<void> _elegirSugerencia(_SugerenciaGoogle sugerencia) async {
    setState(() {
      _sugerencias = [];
      _busquedaController.clear();
      _cargandoDireccion = true;
    });
    _busquedaFocus.unfocus();

    try {
      final uri = Uri.parse(
          'https://places.googleapis.com/v1/places/${sugerencia.placeId}');

      final respuesta = await http.get(
        uri,
        headers: {
          'X-Goog-Api-Key': _googleApiKey,
          'X-Goog-FieldMask': 'location,formattedAddress',
          'sessionToken': _sessionToken,
        },
      );

      if (respuesta.statusCode == 200) {
        final data = jsonDecode(respuesta.body);
        final lat = data['location']?['latitude'];
        final lng = data['location']?['longitude'];
        final direccion = data['formattedAddress'] ??
            '${sugerencia.textoPrincipal}, ${sugerencia.textoSecundario}';

        if (lat != null && lng != null) {
          final nuevoCentro = LatLng(lat, lng);
          setState(() {
            _centro = nuevoCentro;
            _direccionActual = direccion;
          });
          _mapController.move(nuevoCentro, 17);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo obtener esa dirección: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _cargandoDireccion = false);
      // Nueva sesión para la próxima búsqueda.
      _sessionToken = _generarSessionToken();
    }
  }

  void _elegirMiUbicacion() {
    if (_miUbicacionGPS == null) return;

    setState(() {
      _centro = _miUbicacionGPS!;
      _direccionActual = _miDireccionGPS ?? _direccionActual;
    });

    _mapController.move(_miUbicacionGPS!, 17);
    _busquedaFocus.unfocus();
  }

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

  @override
  Widget build(BuildContext context) {
    final mostrarMiUbicacion = _busquedaFocus.hasFocus &&
        _busquedaController.text.trim().isEmpty &&
        _miUbicacionGPS != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('¿Dónde es el servicio?'),
      ),
      body: _cargandoUbicacionInicial
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.clienteAccent))
          : GestureDetector(
              onTap: () => _busquedaFocus.unfocus(),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _centro,
                      initialZoom: 16,
                      onPositionChanged: (posicion, hasGesto) {
                        if (hasGesto && posicion.center != null) {
                          _onMapaSeMovio(posicion.center!);
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.tecnigo',
                      ),
                    ],
                  ),

                  const IgnorePointer(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 40),
                        child: Icon(
                          Icons.location_on,
                          color: AppColors.clienteAccent,
                          size: 48,
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 14,
                    left: 14,
                    right: 14,
                    child: Column(
                      children: [
                        Material(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          elevation: 4,
                          child: TextField(
                            controller: _busquedaController,
                            focusNode: _busquedaFocus,
                            style: const TextStyle(color: AppColors.text),
                            decoration: InputDecoration(
                              hintText: 'Busca tu dirección',
                              hintStyle:
                                  const TextStyle(color: AppColors.subtitle),
                              prefixIcon: const Icon(Icons.search,
                                  color: AppColors.subtitle),
                              suffixIcon: _buscando
                                  ? const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.clienteAccent,
                                        ),
                                      ),
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: AppColors.surface,
                            ),
                            onChanged: (texto) {
                              setState(() {});
                              _debounceBusqueda?.cancel();
                              _debounceBusqueda =
                                  Timer(const Duration(milliseconds: 400), () {
                                _buscarDireccion(texto);
                              });
                            },
                          ),
                        ),

                        if (mostrarMiUbicacion)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: ListTile(
                              leading: const Icon(Icons.my_location,
                                  color: AppColors.clienteAccent),
                              title: const Text(
                                'Usar mi ubicación actual',
                                style: TextStyle(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                _miDireccionGPS ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.subtitle),
                              ),
                              onTap: _elegirMiUbicacion,
                            ),
                          ),

                        if (_sugerencias.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _sugerencias.length,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1, color: AppColors.border),
                              itemBuilder: (context, index) {
                                final s = _sugerencias[index];
                                return ListTile(
                                  leading: const Icon(
                                      Icons.location_on_outlined,
                                      color: AppColors.clienteAccent),
                                  title: Text(
                                    s.textoPrincipal,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.text,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: s.textoSecundario.isNotEmpty
                                      ? Text(
                                          s.textoSecundario,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: AppColors.subtitle),
                                        )
                                      : null,
                                  onTap: () => _elegirSugerencia(s),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),

                  Positioned(
                    right: 14,
                    bottom: 150,
                    child: FloatingActionButton.small(
                      heroTag: 'mi_ubicacion_picker',
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.clienteAccent,
                      onPressed: _miUbicacionGPS == null
                          ? null
                          : _elegirMiUbicacion,
                      child: const Icon(Icons.my_location),
                    ),
                  ),

                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.place,
                                  color: AppColors.clienteAccent, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _cargandoDireccion
                                    ? const Text(
                                        'Ubicando dirección...',
                                        style: TextStyle(
                                            color: AppColors.subtitle),
                                      )
                                    : Text(
                                        _direccionActual,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.text,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.clienteAccent,
                                foregroundColor: Colors.white,
                              ),
                              onPressed:
                                  _cargandoDireccion ? null : _confirmar,
                              child: const Text('Confirmar ubicación'),
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