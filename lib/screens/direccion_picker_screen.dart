@@ -0,0 +1,532 @@
import 'dart:async';
import 'dart:convert';
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

/// Pantalla para elegir dónde va el servicio, al estilo Yango/DiDi:
/// un pin fijo en el centro de la pantalla, y el mapa se arrastra por
/// debajo para ajustarlo. También se puede buscar la dirección escrita
/// (usando el buscador gratuito de OpenStreetMap, sin costo).
class DireccionPickerScreen extends StatefulWidget {
  const DireccionPickerScreen({super.key});

  @override
  State<DireccionPickerScreen> createState() => _DireccionPickerScreenState();
}

class _DireccionPickerScreenState extends State<DireccionPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _busquedaController = TextEditingController();
  final FocusNode _busquedaFocus = FocusNode();

  LatLng _centro = const LatLng(4.7110, -74.0721); // Bogotá, de respaldo
  String _direccionActual = 'Mueve el mapa para ubicar el sitio';

  // Guardamos aparte la ubicación GPS real (no la del pin, que puede
  // moverse), para poder ofrecerla como "mi ubicación actual".
  LatLng? _miUbicacionGPS;
  String? _miDireccionGPS;

  List<Map<String, dynamic>> _sugerencias = [];
  Timer? _debounceBusqueda;
  bool _cargandoUbicacionInicial = true;
  bool _cargandoDireccion = false;
  bool _buscando = false;

  @override
  void initState() {
    super.initState();
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

  void _onFocoBusqueda() {
    if (_busquedaFocus.hasFocus && _busquedaController.text.trim().isEmpty) {
      // Al tocar el buscador sin haber escrito nada, mostramos la
      // ubicación GPS actual como primera opción rápida.
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
      final direccion = await _consultarDireccion(_centro);
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

  // Arma una versión corta y legible de la dirección (calle + barrio +
  // ciudad). Si el lugar no tiene calle/número (por ejemplo, cuando se
  // busca un barrio), evitamos mostrar términos técnicos como "UPZs de
  // Bogotá" y nos quedamos solo con el nombre del lugar + la ciudad.
  String _direccionCorta(Map<String, dynamic> data) {
    final direccionCompleta = data['address'] as Map<String, dynamic>?;

    if (direccionCompleta != null) {
      final calle = direccionCompleta['road'] ??
          direccionCompleta['pedestrian'] ??
          direccionCompleta['residential'];
      final numero = direccionCompleta['house_number'];
      final barrio = direccionCompleta['neighbourhood'] ??
          direccionCompleta['suburb'] ??
          direccionCompleta['quarter'];
      final ciudad = direccionCompleta['city'] ??
          direccionCompleta['town'] ??
          direccionCompleta['village'] ??
          direccionCompleta['county'];

      if (calle != null) {
        final partes = <String>[
          numero != null ? '$calle #$numero' : '$calle',
          if (barrio != null) '$barrio',
          if (ciudad != null) '$ciudad',
        ];
        return partes.join(', ');
      }
    }

    // Sin calle (ej. resultado de un barrio/zona): usamos solo el
    // nombre del lugar (primer segmento) y la ciudad (último segmento),
    // sin toda la jerga administrativa que queda en el medio.
    final display = (data['display_name'] ?? '').toString();
    final segmentos =
        display.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    if (segmentos.isEmpty) return display;

    final nombre = segmentos.first;
    final ciudadFinal = segmentos.length > 1 ? segmentos.last : '';

    if (ciudadFinal.isNotEmpty && ciudadFinal != nombre) {
      return '$nombre, $ciudadFinal';
    }
    return nombre;
  }

  Future<String> _consultarDireccion(LatLng punto) async {
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
      final direccion = await _consultarDireccion(_centro);
      if (mounted) setState(() => _direccionActual = direccion);
    });
  }

  int _idBusqueda = 0;

  Future<void> _buscarDireccion(String query) async {
    final idEstaBusqueda = ++_idBusqueda;

    if (query.trim().length < 2) {
      if (mounted) setState(() => _sugerencias = []);
      return;
    }

    setState(() => _buscando = true);

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json&addressdetails=1&limit=5&countrycodes=co',
      );
      final respuesta = await http.get(
        uri,
        headers: {'User-Agent': 'TecniGoApp/1.0'},
      );

      // Si mientras esperábamos la respuesta el usuario ya escribió
      // algo más, esta respuesta quedó vieja: la ignoramos para que no
      // le borre los resultados más recientes al usuario.
      if (idEstaBusqueda != _idBusqueda) return;

      if (respuesta.statusCode == 200) {
        final List data = jsonDecode(respuesta.body);
        if (mounted) {
          setState(() {
            _sugerencias = data.cast<Map<String, dynamic>>();
          });
        }
      }
      // Si la respuesta no fue 200 (por ejemplo, el buscador gratuito
      // bloqueó la petición por ir muy seguido), dejamos la última
      // lista de sugerencias válida en vez de vaciarla.
    } catch (_) {
      // Igual: si falla la conexión, no borramos lo que ya se veía.
    } finally {
      if (mounted && idEstaBusqueda == _idBusqueda) {
        setState(() => _buscando = false);
      }
    }
  }

  void _elegirSugerencia(Map<String, dynamic> sugerencia) {
    final lat = double.parse(sugerencia['lat']);
    final lon = double.parse(sugerencia['lon']);
    final nuevoCentro = LatLng(lat, lon);

    setState(() {
      _sugerencias = [];
      _busquedaController.clear();
      _direccionActual = _direccionCorta(sugerencia);
      _centro = nuevoCentro;
    });

    _mapController.move(nuevoCentro, 17);
    _busquedaFocus.unfocus();
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
                  // Mapa de fondo.
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

                  // Pin fijo en el centro de la pantalla (el mapa se
                  // mueve por debajo, el pin no se mueve).
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

                  // Barra de búsqueda arriba.
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
                                  Timer(const Duration(milliseconds: 700), () {
                                _buscarDireccion(texto);
                              });
                            },
                          ),
                        ),

                        // Opción rápida: usar mi ubicación actual.
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
                                    _direccionCorta(s),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppColors.text),
                                  ),
                                  onTap: () => _elegirSugerencia(s),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Botón "mi ubicación" para volver al GPS actual
                  // directo desde el mapa.
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

                  // Panel inferior con la dirección detectada y botón
                  // de confirmar.
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