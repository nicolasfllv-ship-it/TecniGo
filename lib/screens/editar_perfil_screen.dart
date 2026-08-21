import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tecnigo/theme/app_colors.dart';
import 'package:tecnigo/widgets/scanner_frame.dart';

/// Editar nombre y foto de perfil. Sirve tanto para cliente como para
/// técnico: solo toca los campos 'nombre' y 'fotoBase64' del documento
/// del usuario en Firestore, así que en cuanto se guarda, se actualiza
/// solo en cualquier otra pantalla que ya esté leyendo esos datos en
/// vivo (mi cuenta, servicio en progreso, listas de servicios, etc.).
class EditarPerfilScreen extends StatefulWidget {
  const EditarPerfilScreen({super.key});

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final nombreController = TextEditingController();
  Uint8List? fotoBytes;
  bool cargandoDatos = true;
  bool guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosActuales();
  }

  @override
  void dispose() {
    nombreController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosActuales() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      nombreController.text = (data['nombre'] ?? '').toString();
      if ((data['fotoBase64'] ?? '').toString().isNotEmpty) {
        try {
          fotoBytes = base64Decode(data['fotoBase64']);
        } catch (_) {}
      }
    }

    if (mounted) setState(() => cargandoDatos = false);
  }

  Future<void> _elegirFoto() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.primary),
              title: const Text('Tomar foto',
                  style: TextStyle(color: AppColors.text)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.primary),
              title: const Text('Elegir de la galería',
                  style: TextStyle(color: AppColors.text)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (origen == null) return;

    final picker = ImagePicker();
    final XFile? archivo = await picker.pickImage(
      source: origen,
      maxWidth: 300,
      imageQuality: 60,
    );
    if (archivo == null) return;

    final bytes = await archivo.readAsBytes();
    setState(() => fotoBytes = bytes);
  }

  Future<void> _guardar() async {
    if (guardando) return;

    final nombre = nombreController.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa tu nombre')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => guardando = true);

    try {
      final Map<String, dynamic> datos = {'nombre': nombre};
      if (fotoBytes != null) {
        datos['fotoBase64'] = base64Encode(fotoBytes!);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(datos);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Editar perfil')),
      body: cargandoDatos
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _elegirFoto,
                    child: ScannerFrame(
                      tamano: 14,
                      grosor: 2,
                      child: CircleAvatar(
                        radius: 55,
                        backgroundColor: AppColors.surface,
                        backgroundImage:
                            fotoBytes != null ? MemoryImage(fotoBytes!) : null,
                        child: fotoBytes == null
                            ? const Icon(Icons.add_a_photo_outlined,
                                color: AppColors.subtitle, size: 34)
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: _elegirFoto,
                    child: Text(
                      fotoBytes == null ? 'Agregar foto' : 'Cambiar foto',
                      style: const TextStyle(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nombreController,
                  style: const TextStyle(color: AppColors.text),
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: guardando ? null : _guardar,
                    child: guardando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: AppColors.background,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text('Guardar cambios'),
                  ),
                ),
              ],
            ),
    );
  }
}