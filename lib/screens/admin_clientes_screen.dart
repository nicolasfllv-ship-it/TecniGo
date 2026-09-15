import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tecnigo/screens/admin_usuario_detalle_screen.dart';
import 'package:tecnigo/theme/app_colors.dart';

class AdminClientesScreen extends StatefulWidget {
  const AdminClientesScreen({super.key});

  @override
  State<AdminClientesScreen> createState() => _AdminClientesScreenState();
}

class _AdminClientesScreenState extends State<AdminClientesScreen> {
  final TextEditingController _buscadorController = TextEditingController();
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _buscadorController.addListener(() {
      setState(() => _busqueda = _buscadorController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _buscadorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      // Limita el ancho de la lista en pantallas grandes manteniendo el
      // mismo breakpoint (>= 900) que usa el dashboard del panel admin.
      body: LayoutBuilder(
        builder: (context, constraints) {
          final anchoMaximo =
              constraints.maxWidth >= 900 ? 840.0 : double.infinity;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: anchoMaximo),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      controller: _buscadorController,
                      style: const TextStyle(color: AppColors.text),
                      decoration: const InputDecoration(
                        hintText: 'Buscar por nombre o correo',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No se pudieron cargar los clientes:\n'
                                '${snapshot.error}',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final clientes = _filtrarClientes(snapshot.data!);

                        if (clientes.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _busqueda.isEmpty
                                    ? 'No hay clientes registrados.'
                                    : 'No se encontraron clientes para esa búsqueda.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.subtitle,
                                ),
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: clientes.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) =>
                              _ClienteCard(cliente: clientes[index]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtrarClientes(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final docs = snapshot.docs.where((doc) {
      final datos = doc.data();
      // Solo usuarios con rol exacto 'cliente'.
      if ((datos['rol'] ?? '').toString() != 'cliente') return false;

      if (_busqueda.isEmpty) return true;
      final nombre = (datos['nombre'] ?? '').toString().toLowerCase();
      final correo = (datos['email'] ?? '').toString().toLowerCase();
      return nombre.contains(_busqueda) || correo.contains(_busqueda);
    }).toList();

    // Orden alfabético por nombre.
    docs.sort((a, b) {
      final nombreA = (a.data()['nombre'] ?? '').toString();
      final nombreB = (b.data()['nombre'] ?? '').toString();
      return nombreA.toLowerCase().compareTo(nombreB.toLowerCase());
    });

    return docs;
  }
}

class _ClienteCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> cliente;

  const _ClienteCard({required this.cliente});

  @override
  Widget build(BuildContext context) {
    final datos = cliente.data();
    final foto = _fotoDesdeDatos(datos);
    final nombre = _textoORespaldo(datos['nombre'], 'Sin nombre');
    final correo = _textoORespaldo(datos['email'], 'Sin correo');

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.primary,
          backgroundImage: foto != null ? MemoryImage(foto) : null,
          child: foto == null
              ? const Icon(
                  Icons.person,
                  color: AppColors.background,
                  size: 28,
                )
              : null,
        ),
        title: Text(
          nombre,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Text(correo),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminUsuarioDetalleScreen(usuarioId: cliente.id),
            ),
          );
        },
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