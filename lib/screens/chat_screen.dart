import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tecnigo/theme/app_colors.dart';

/// Chat en tiempo real entre cliente y técnico, ligado a un servicio.
///
/// Uso (desde seguimiento_screen.dart u otra pantalla):
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => ChatScreen(
///     servicioId: servicio.id,
///     miUid: FirebaseAuth.instance.currentUser!.uid,
///     miRol: 'cliente', // o 'tecnico'
///     nombreOtro: 'Juan Pérez', // nombre de la otra persona, para el AppBar
///   ),
/// ));
class ChatScreen extends StatefulWidget {
  final String servicioId;
  final String miUid;
  final String miRol; // 'cliente' o 'tecnico'
  final String nombreOtro;

  const ChatScreen({
    super.key,
    required this.servicioId,
    required this.miUid,
    required this.miRol,
    required this.nombreOtro,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  CollectionReference<Map<String, dynamic>> get _mensajesRef =>
      FirebaseFirestore.instance
          .collection('servicios')
          .doc(widget.servicioId)
          .collection('mensajes');

  Future<void> _enviarMensaje() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty) return;

    _controller.clear();

    await _mensajesRef.add({
      'texto': texto,
      'emisorId': widget.miUid,
      'emisorRol': widget.miRol,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Baja el scroll al último mensaje enviado.
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          widget.nombreOtro,
          style: const TextStyle(color: AppColors.text),
        ),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _mensajesRef
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      "No se pudieron cargar los mensajes",
                      style: TextStyle(color: AppColors.subtitle),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "Todavía no hay mensajes.\n¡Escribe el primero!",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.subtitle),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final esMio = data['emisorId'] == widget.miUid;
                    return _BurbujaMensaje(
                      texto: data['texto'] ?? '',
                      esMio: esMio,
                    );
                  },
                );
              },
            ),
          ),
          _CampoDeTexto(
            controller: _controller,
            onEnviar: _enviarMensaje,
          ),
        ],
      ),
    );
  }
}

class _BurbujaMensaje extends StatelessWidget {
  final String texto;
  final bool esMio;

  const _BurbujaMensaje({required this.texto, required this.esMio});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: esMio ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(esMio ? 16 : 4),
            bottomRight: Radius.circular(esMio ? 4 : 16),
          ),
          border: esMio ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: esMio ? AppColors.background : AppColors.text,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _CampoDeTexto extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onEnviar;

  const _CampoDeTexto({required this.controller, required this.onEnviar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: AppColors.text),
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Escribe un mensaje...",
                  hintStyle: const TextStyle(color: AppColors.subtitle),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => onEnviar(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary,
              child: IconButton(
                icon: const Icon(Icons.send, color: AppColors.background, size: 20),
                onPressed: onEnviar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}