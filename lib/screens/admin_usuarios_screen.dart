import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tecnigo/screens/admin_usuario_detalle_screen.dart';
import 'package:tecnigo/theme/app_colors.dart';

class AdminUsuariosScreen extends StatefulWidget {
  const AdminUsuariosScreen({super.key});

  @override
  State<AdminUsuariosScreen> createState() => _AdminUsuariosScreenState();
}

class _AdminUsuariosScreenState extends State<AdminUsuariosScreen> {
  final TextEditingController _buscadorController = TextEditingController();
  String _busqueda = '';
  String _rolSeleccionado = 'todos';

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
      appBar: AppBar(title: const Text('Usuarios')),
      body: Column(
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                _FiltroRol(
                  etiqueta: 'Todos',
                  valor: 'todos',
                  seleccionado: _rolSeleccionado,
                  onSelected: _seleccionarRol,
                ),
                _FiltroRol(
                  etiqueta: 'Clientes',
                  valor: 'cliente',
                  seleccionado: _rolSeleccionado,
                  onSelected: _seleccionarRol,
                ),
                _FiltroRol(
                  etiqueta: 'Técnicos',
                  valor: 'tecnico',
                  seleccionado: _rolSeleccionado,
                  onSelected: _seleccionarRol,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No se pudieron cargar los usuarios:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final usuarios = snapshot.data!.docs.where((usuario) {
                  final datos = usuario.data();
                  final rol = (datos['rol'] ?? '').toString().toLowerCase();
                  final nombre = (datos['nombre'] ?? '').toString().toLowerCase();
                  final correo = (datos['email'] ?? '').toString().toLowerCase();
                  final coincideRol = _rolSeleccionado == 'todos' ||
                      rol == _rolSeleccionado;
                  final coincideBusqueda = _busqueda.isEmpty ||
                      nombre.contains(_busqueda) ||
                      correo.contains(_busqueda);
                  return coincideRol && coincideBusqueda;
                }).toList()
                  ..sort((a, b) {
                    final nombreA = (a.data()['nombre'] ?? '').toString();
                    final nombreB = (b.data()['nombre'] ?? '').toString();
                    return nombreA.toLowerCase().compareTo(nombreB.toLowerCase());
                  });

                if (usuarios.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _busqueda.isEmpty && _rolSeleccionado == 'todos'
                            ? 'No hay usuarios registrados.'
                            : 'No se encontraron usuarios con esos filtros.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.subtitle),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: usuarios.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final usuario = usuarios[index];
                    final datos = usuario.data();
                    final foto = _fotoDesdeDatos(datos);
                    final rol = (datos['rol'] ?? '').toString();

                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary,
                          backgroundImage: foto != null ? MemoryImage(foto) : null,
                          child: foto == null
                              ? const Icon(
                                  Icons.person,
                                  color: AppColors.background,
                                )
                              : null,
                        ),
                        title: Text(
                          _textoORespaldo(datos['nombre'], 'Sin nombre'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 3),
                            Text(_textoORespaldo(datos['email'], 'Sin correo')),
                            const SizedBox(height: 4),
                            _RolEtiqueta(rol: rol),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminUsuarioDetalleScreen(
                                usuarioId: usuario.id,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _seleccionarRol(String rol) {
    setState(() => _rolSeleccionado = rol);
  }
}

class _FiltroRol extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final String seleccionado;
  final ValueChanged<String> onSelected;

  const _FiltroRol({
    required this.etiqueta,
    required this.valor,
    required this.seleccionado,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(etiqueta),
      selected: seleccionado == valor,
      onSelected: (_) => onSelected(valor),
    );
  }
}

class _RolEtiqueta extends StatelessWidget {
  final String rol;

  const _RolEtiqueta({required this.rol});

  @override
  Widget build(BuildContext context) {
    final etiqueta = switch (rol) {
      'cliente' => 'Cliente',
      'tecnico' => 'Técnico',
      'admin' => 'Administrador',
      _ => rol.isEmpty ? 'Sin rol' : rol,
    };

    return Text(
      etiqueta,
      style: const TextStyle(
        color: AppColors.subtitle,
        fontSize: 12,
        fontWeight: FontWeight.w600,
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