import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Resultado del cálculo de ruta entre el técnico y el cliente.
class RutaInfo {
  final double distanciaKm;
  final int minutosEstimados;
  final List<LatLng> puntosRuta;

  RutaInfo({
    required this.distanciaKm,
    required this.minutosEstimados,
    required this.puntosRuta,
  });
}

class EtaService {
  // Servidor público de OSRM (gratuito, sin necesidad de API key).
  // Para producción real más adelante conviene montar un servidor propio,
  // pero para el MVP y la sustentación esto es suficiente.
  static const String _baseUrl = 'https://router.project-osrm.org';

  /// Pide la ruta real por calles entre el técnico y el cliente.
  /// Si falla la conexión (sin internet, servidor caído, etc.), usa un
  /// cálculo aproximado en línea recta para que la app no se rompa.
  static Future<RutaInfo> calcularRuta({
    required LatLng origenTecnico,
    required LatLng destinoCliente,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/route/v1/driving/'
        '${origenTecnico.longitude},${origenTecnico.latitude};'
        '${destinoCliente.longitude},${destinoCliente.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final ruta = data['routes'][0];
          final distanciaMetros = (ruta['distance'] as num).toDouble();
          final duracionSegundos = (ruta['duration'] as num).toDouble();

          final coords = ruta['geometry']['coordinates'] as List;
          final puntos = coords
              .map<LatLng>(
                (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
              )
              .toList();

          return RutaInfo(
            distanciaKm: distanciaMetros / 1000,
            minutosEstimados: (duracionSegundos / 60).ceil(),
            puntosRuta: puntos,
          );
        }
      }
    } catch (_) {
      // Sin internet o el servicio de rutas no respondió a tiempo.
      // Seguimos con el cálculo aproximado de respaldo (más abajo).
    }

    return _rutaAproximada(origenTecnico, destinoCliente);
  }

  /// Cálculo de respaldo: distancia en línea recta + una velocidad
  /// promedio urbana (30 km/h) para estimar el tiempo si OSRM no responde.
  static RutaInfo _rutaAproximada(LatLng origen, LatLng destino) {
    const Distance distanciaCalc = Distance();
    final metros = distanciaCalc(origen, destino);
    final km = metros / 1000;

    const velocidadPromedioKmH = 30;
    final horas = km / velocidadPromedioKmH;
    final minutos = max(1, (horas * 60).ceil());

    return RutaInfo(
      distanciaKm: km,
      minutosEstimados: minutos,
      puntosRuta: [origen, destino],
    );
  }
}
