import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tecnigo/theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'cliente_main_screen.dart';
import 'home_tecnico_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formPaso1 = GlobalKey<FormState>();
  final _formPaso2 = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String selectedRole = 'cliente';
  bool cargando = false;
  int pasoActual = 0;

  Uint8List? fotoBytes;

  static const _titulosPaso = ['Cuenta', 'Acceso', 'Foto'];

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
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

  void _siguientePaso() {
    if (pasoActual == 0) {
      if (!_formPaso1.currentState!.validate()) return;
      setState(() => pasoActual = 1);
    } else if (pasoActual == 1) {
      if (!_formPaso2.currentState!.validate()) return;
      setState(() => pasoActual = 2);
    } else {
      registerUser();
    }
  }

  void _pasoAnterior() {
    if (pasoActual == 0) {
      Navigator.pop(context);
    } else {
      setState(() => pasoActual -= 1);
    }
  }

  Future<void> registerUser() async {
    // Evita que dos toques rápidos manden el formulario dos veces.
    if (cargando) return;

    setState(() => cargando = true);

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = userCredential.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'nombre': nameController.text.trim(),
        'email': emailController.text.trim(),
        'rol': selectedRole,
        'fechaRegistro': DateTime.now(),
      });

      // La foto es opcional: la guardamos codificada en base64 dentro
      // del propio documento del usuario (sin usar Firebase Storage,
      // que requiere el plan Blaze). Por eso la foto se reduce a
      // 300px de ancho al elegirla: para que quepa cómoda dentro del
      // límite de 1MB que tiene cada documento de Firestore.
      if (fotoBytes != null) {
        try {
          final fotoBase64 = base64Encode(fotoBytes!);
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .update({'fotoBase64': fotoBase64});
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'La cuenta se creó, pero la foto no se pudo guardar: $e'),
              ),
            );
          }
        }
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => selectedRole == 'tecnico'
              ? const HomeTecnicoScreen()
              : const ClienteMainScreen(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String mensaje;
      if (e.code == 'network-request-failed') {
        mensaje = 'Sin conexión a internet. Verifica tu conexión e '
            'intenta de nuevo.';
      } else if (e.code == 'email-already-in-use') {
        mensaje = 'Ese correo ya está registrado';
      } else if (e.code == 'weak-password') {
        mensaje = 'La contraseña es muy débil';
      } else {
        mensaje = e.message ?? 'Error al registrar usuario';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado: $e')),
      );
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: cargando ? null : _pasoAnterior,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _IndicadorPasos(pasoActual: pasoActual, titulos: _titulosPaso),
            const SizedBox(height: 30),
            Expanded(
              child: SingleChildScrollView(
                child: IndexedStack(
                  index: pasoActual,
                  children: [
                    _PasoCuenta(formKey: _formPaso1, nameController: nameController, selectedRole: selectedRole, onRoleChanged: (v) => setState(() => selectedRole = v)),
                    _PasoAcceso(formKey: _formPaso2, emailController: emailController, passwordController: passwordController),
                    _PasoFoto(fotoBytes: fotoBytes, onElegirFoto: _elegirFoto, onQuitarFoto: () => setState(() => fotoBytes = null)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: cargando ? null : _siguientePaso,
                child: cargando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: AppColors.background,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(pasoActual < 2
                        ? 'Continuar'
                        : (fotoBytes == null
                            ? 'Finalizar sin foto'
                            : 'Finalizar registro')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IndicadorPasos extends StatelessWidget {
  final int pasoActual;
  final List<String> titulos;

  const _IndicadorPasos({required this.pasoActual, required this.titulos});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(titulos.length, (i) {
        final activo = i <= pasoActual;
        return Expanded(
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: activo ? AppColors.primary : AppColors.surface,
                      border: Border.all(
                        color: activo ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: i < pasoActual
                        ? const Icon(Icons.check,
                            size: 16, color: AppColors.background)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: activo
                                  ? AppColors.background
                                  : AppColors.subtitle,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    titulos[i],
                    style: TextStyle(
                      fontSize: 11,
                      color: activo ? AppColors.text : AppColors.subtitle,
                    ),
                  ),
                ],
              ),
              if (i != titulos.length - 1)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    height: 2,
                    color: i < pasoActual
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _PasoCuenta extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final String selectedRole;
  final ValueChanged<String> onRoleChanged;

  const _PasoCuenta({
    required this.formKey,
    required this.nameController,
    required this.selectedRole,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Cómo te llamas?',
            style: TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Y con qué rol vas a usar TecniGo',
            style: TextStyle(color: AppColors.subtitle, fontSize: 13),
          ),
          const SizedBox(height: 22),
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa tu nombre';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: selectedRole,
            decoration: const InputDecoration(
              labelText: 'Tipo de usuario',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'cliente', child: Text('Cliente')),
              DropdownMenuItem(value: 'tecnico', child: Text('Técnico')),
            ],
            onChanged: (value) => onRoleChanged(value!),
          ),
        ],
      ),
    );
  }
}

class _PasoAcceso extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;

  const _PasoAcceso({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Datos de acceso',
            style: TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Con esto vas a iniciar sesión la próxima vez',
            style: TextStyle(color: AppColors.subtitle, fontSize: 13),
          ),
          const SizedBox(height: 22),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa tu correo';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return 'Ingresa un correo válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Contraseña',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa una contraseña';
              }
              if (value.length < 6) {
                return 'Debe tener al menos 6 caracteres';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class _PasoFoto extends StatelessWidget {
  final Uint8List? fotoBytes;
  final VoidCallback onElegirFoto;
  final VoidCallback onQuitarFoto;

  const _PasoFoto({
    required this.fotoBytes,
    required this.onElegirFoto,
    required this.onQuitarFoto,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto de perfil',
          style: TextStyle(
              color: AppColors.text, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Es opcional — puedes agregarla después desde tu cuenta',
          style: TextStyle(color: AppColors.subtitle, fontSize: 13),
        ),
        const SizedBox(height: 26),
        Center(
          child: GestureDetector(
            onTap: onElegirFoto,
            child: CircleAvatar(
              radius: 60,
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
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: fotoBytes == null ? onElegirFoto : onQuitarFoto,
            icon: Icon(
              fotoBytes == null ? Icons.photo_library_outlined : Icons.close,
              color: AppColors.primary,
            ),
            label: Text(
              fotoBytes == null ? 'Elegir de la galería' : 'Quitar foto',
              style: const TextStyle(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}