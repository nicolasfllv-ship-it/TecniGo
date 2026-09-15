import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tecnigo/theme/app_colors.dart';

class AdminServicioDetalleScreen extends StatelessWidget {
  final String servicioId;

  const AdminServicioDetalleScreen({
    super.key,
    required this.servicioId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de servicio')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('servicios')
            .doc(servicioId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo cargar el servicio:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            return const Center(child: Text('Este servicio ya no existe.'));
          }

          final datos = snapshot.data!.data()!;

          final clienteId = (datos['clienteId'] ?? '').toString();
          final tecnicoId = (datos['tecnicoId'] ?? '').toString();

          return FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
            future: _leerUsuarios(clienteId, tecnicoId),
            builder: (context, userSnapshot) {
              Map<String, dynamic>? clienteData;
              Map<String, dynamic>? tecnicoData;

              if (userSnapshot.hasData) {
                final results = userSnapshot.data!;
                if (results.isNotEmpty) clienteData = results[0].data();
                if (results.length > 1) tecnicoData = results[1].data();
              }

              final clienteNombre = _textoORespaldo(
                clienteData?['nombre'],
                (datos['emailCliente'] ?? 'Sin email').toString(),
              );
              final clienteEmail = _textoORespaldo(
                clienteData?['email'],
                datos['emailCliente'],
              );
              final clienteUid = _textoORespaldo(
                clienteData?['uid'],
                clienteId,
              );

              String tecnicoNombre = 'Sin asignar';
              String tecnicoEmail = 'Sin asignar';
              String tecnicoUid = 'Sin asignar';

              if (tecnicoId.isNotEmpty) {
                tecnicoNombre = _textoORespaldo(
                  tecnicoData?['nombre'],
                  (datos['tecnicoEmail'] ?? 'Sin email').toString(),
                );
                tecnicoEmail = _textoORespaldo(
                  tecnicoData?['email'],
                  datos['tecnicoEmail'],
                );
                tecnicoUid = _textoORespaldo(
                  tecnicoData?['uid'],
                  tecnicoId,
                );
              }

              final estado = (datos['estado'] ?? '').toString();
              final estadoColor = _colorEstado(estado);

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _Seccion(titulo: 'Servicio'),
                  _DetalleFila(etiqueta: 'Tipo', valor: _textoORespaldo(datos['tipoServicio'], 'Sin tipo')),
                  _DetalleFila(etiqueta: 'Descripción', valor: _textoORespaldo(datos['descripcion'], 'Sin descripción')),
                  _DetalleFila(etiqueta: 'Dirección', valor: _textoORespaldo(datos['direccion'], 'Sin dirección')),
                  _DetalleFila(etiqueta: 'ID', valor: servicioId, fontFamily: 'monospace'),

                  const SizedBox(height: 22),
                  _Seccion(titulo: 'Fechas'),
                  _DetalleFila(etiqueta: 'Creación', valor: _fechaLegible(datos['fecha'])),
                  if (datos.containsKey('fechaAceptacion') && datos['fechaAceptacion'] != null)
                    _DetalleFila(etiqueta: 'Aceptación', valor: _fechaLegible(datos['fechaAceptacion'])),
                  if (datos.containsKey('fechaFinalizacion') && datos['fechaFinalizacion'] != null)
                    _DetalleFila(etiqueta: 'Finalización', valor: _fechaLegible(datos['fechaFinalizacion'])),

                  const SizedBox(height: 22),
                  _Seccion(titulo: 'Cliente'),
                  _DetalleFila(etiqueta: 'Nombre', valor: clienteNombre),
                  _DetalleFila(etiqueta: 'Email', valor: _textoORespaldo(clienteEmail, 'Sin correo')),
                  _DetalleFila(etiqueta: 'UID', valor: clienteUid, fontFamily: 'monospace'),

                  const SizedBox(height: 22),
                  _Seccion(titulo: 'Técnico'),
                  _DetalleFila(etiqueta: 'Nombre', valor: tecnicoNombre),
                  _DetalleFila(etiqueta: 'Email', valor: tecnicoEmail),
                  _DetalleFila(etiqueta: 'UID', valor: tecnicoUid, fontFamily: 'monospace'),

                  const SizedBox(height: 22),
                  _Seccion(titulo: 'Estado'),
                  _DetalleFila(
                    etiqueta: 'Estado',
                    valor: _estadoLegible(estado),
                    valorColor: estadoColor,
                    valorFontWeight: FontWeight.w600,
                  ),

                  const SizedBox(height: 22),
                  _Seccion(titulo: 'Calificación y reportes'),
                  _DetalleFila(
                    etiqueta: 'Calificado',
                    valor: datos['calificado'] == true ? 'Sí' : 'No',
                  ),
                  _DetalleFila(
                    etiqueta: 'Confirmado por cliente',
                    valor: datos['confirmadoCliente'] == true ? 'Sí' : 'No',
                  ),
                  _DetalleFila(
                    etiqueta: 'Reportado',
                    valor: datos['reportado'] == true ? 'Sí' : 'No',
                    valorColor: datos['reportado'] == true ? AppColors.error : null,
                  ),
                  if (datos['reportado'] == true && datos.containsKey('motivoReporte') && datos['motivoReporte'] != null) ...[
                    _DetalleFila(etiqueta: 'Motivo del reporte', valor: (datos['motivoReporte'] ?? '').toString()),
                    _DetalleFila(etiqueta: 'Fecha del reporte', valor: _fechaLegible(datos['fechaReporte'])),
                  ],

                  const SizedBox(height: 22),
                  _Seccion(titulo: 'Ubicación'),
                  if (datos.containsKey('lat') && datos.containsKey('lng')) ...[
                    _DetalleFila(etiqueta: 'Latitud', valor: _coordenadaLegible(datos['lat'])),
                    _DetalleFila(etiqueta: 'Longitud', valor: _coordenadaLegible(datos['lng'])),
                  ] else ...[
                    _DetalleFila(etiqueta: 'Latitud', valor: 'No disponible'),
                    _DetalleFila(etiqueta: 'Longitud', valor: 'No disponible'),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> _leerUsuarios(
    String clienteId,
    String tecnicoId,
  ) async {
    final futures = <Future<DocumentSnapshot<Map<String, dynamic>>>>[];
    futures.add(FirebaseFirestore.instance.collection('users').doc(clienteId).get());
    if (tecnicoId.isNotEmpty) {
      futures.add(FirebaseFirestore.instance.collection('users').doc(tecnicoId).get());
    }
    return Future.wait(futures);
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return AppColors.accent;
      case 'aceptado':
        return AppColors.clienteAccent;
      case 'en camino':
        return AppColors.clienteAccent;
      case 'trabajando':
        return AppColors.tecnicoAccent;
      case 'finalizado':
        return AppColors.success;
      case 'cancelado':
        return AppColors.error;
      default:
        return AppColors.subtitle;
    }
  }

  String _estadoLegible(String estado) {
    switch (estado) {
      case 'pendiente':
        return 'Pendiente';
      case 'aceptado':
        return 'Aceptado';
      case 'en camino':
        return 'En camino';
      case 'trabajando':
        return 'Trabajando';
      case 'finalizado':
        return 'Finalizado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return estado.isEmpty ? 'Desconocido' : estado;
    }
  }

  String _fechaLegible(dynamic valor) {
    DateTime? fecha;
    if (valor is Timestamp) {
      fecha = valor.toDate();
    } else if (valor is DateTime) {
      fecha = valor;
    }

    if (fecha == null) {
      return valor == null ? 'No disponible' : valor.toString();
    }

    String dosDigitos(int numero) => numero.toString().padLeft(2, '0');
    return '${dosDigitos(fecha.day)}/${dosDigitos(fecha.month)}/${fecha.year} '
        '${dosDigitos(fecha.hour)}:${dosDigitos(fecha.minute)}';
  }

  String _coordenadaLegible(dynamic valor) {
    if (valor is num) return valor.toDouble().toStringAsFixed(6);
    return _textoORespaldo(valor, 'No disponible');
  }

  String _textoORespaldo(dynamic valor, String respaldo) {
    final texto = (valor ?? '').toString().trim();
    return texto.isEmpty ? respaldo : texto;
  }
}

class _Seccion extends StatelessWidget {
  final String titulo;

  const _Seccion({required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        titulo,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _DetalleFila extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final Color? valorColor;
  final FontWeight? valorFontWeight;
  final String? fontFamily;

  const _DetalleFila({
    required this.etiqueta,
    required this.valor,
    this.valorColor,
    this.valorFontWeight,
    this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: const TextStyle(
              color: AppColors.subtitle,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            valor,
            style: TextStyle(
              color: valorColor,
              fontWeight: valorFontWeight,
              fontFamily: fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}