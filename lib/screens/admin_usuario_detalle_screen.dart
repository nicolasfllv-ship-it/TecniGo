import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tecnigo/theme/app_colors.dart';

class AdminUsuarioDetalleScreen extends StatelessWidget {
  final String usuarioId;

  const AdminUsuarioDetalleScreen({
    super.key,
    required this.usuarioId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de usuario')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(usuarioId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo cargar el usuario:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            return const Center(child: Text('Este usuario ya no existe.'));
          }

          final datos = snapshot.data!.data()!;
          final foto = _fotoDesdeDatos(datos);
          final nombre = _textoORespaldo(datos['nombre'], 'Sin nombre');
          final rol = (datos['rol'] ?? '').toString();
          final esTecnico = rol == 'tecnico';
          final tieneUbicacionTecnico = esTecnico &&
              (datos.containsKey('disponible') ||
                  datos.containsKey('lat') ||
                  datos.containsKey('lng') ||
                  datos.containsKey('ubicacionActualizada'));

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 54,
                  backgroundColor: AppColors.surface,
                  backgroundImage: foto != null ? MemoryImage(foto) : null,
                  child: foto == null
                      ? const Icon(
                          Icons.person,
                          color: AppColors.subtitle,
                          size: 48,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                nombre,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                _rolLegible(rol),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.subtitle),
              ),
              const SizedBox(height: 24),
              const _Seccion(titulo: 'Información de la cuenta'),
              _DetalleFila(
                etiqueta: 'Nombre',
                valor: nombre,
              ),
              _DetalleFila(
                etiqueta: 'Correo',
                valor: _textoORespaldo(datos['email'], 'Sin correo'),
              ),
              _DetalleFila(etiqueta: 'Rol', valor: _rolLegible(rol)),
              _DetalleFila(
                etiqueta: 'UID',
                valor: _textoORespaldo(datos['uid'], usuarioId),
              ),
              _DetalleFila(
                etiqueta: 'Fecha de registro',
                valor: _fechaLegible(datos['fechaRegistro']),
              ),
              if (tieneUbicacionTecnico) ...[
                const SizedBox(height: 22),
                const _Seccion(titulo: 'Información técnica'),
                if (datos.containsKey('disponible'))
                  _DetalleFila(
                    etiqueta: 'Disponibilidad',
                    valor: datos['disponible'] == true
                        ? 'Disponible'
                        : 'No disponible',
                  ),
                if (datos.containsKey('lat'))
                  _DetalleFila(
                    etiqueta: 'Latitud',
                    valor: _coordenadaLegible(datos['lat']),
                  ),
                if (datos.containsKey('lng'))
                  _DetalleFila(
                    etiqueta: 'Longitud',
                    valor: _coordenadaLegible(datos['lng']),
                  ),
                if (datos.containsKey('ubicacionActualizada'))
                  _DetalleFila(
                    etiqueta: 'Ubicación actualizada',
                    valor: _fechaLegible(datos['ubicacionActualizada']),
                  ),
              ],
            ],
          );
        },
      ),
    );
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

  const _DetalleFila({
    required this.etiqueta,
    required this.valor,
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
          SelectableText(valor),
        ],
      ),
    );
  }
}

Uint8List? _fotoDesdeDatos(Map<String, dynamic> datos) {
  final fotoBase64 = (datos['fotoBase64'] ?? '').toString();
  if (fotoBase64.isEmpty) return null;

  try {
    return base64Decode(fotoBase64);
  } catch (_) {
    return null;
  }
}

String _textoORespaldo(dynamic valor, String respaldo) {
  final texto = (valor ?? '').toString().trim();
  return texto.isEmpty ? respaldo : texto;
}

String _rolLegible(String rol) {
  return switch (rol) {
    'cliente' => 'Cliente',
    'tecnico' => 'Técnico',
    'admin' => 'Administrador',
    _ => rol.isEmpty ? 'Sin rol' : rol,
  };
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