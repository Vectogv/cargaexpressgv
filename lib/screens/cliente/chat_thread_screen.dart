import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/socket_service_client.dart';
import '../../widgets/error_carga.dart';

class ChatThreadScreen extends StatefulWidget {
  final String titulo;
  final String subtitulo;
  final String threadId;
  final String idField;
  final Future<List<Map<String, dynamic>>> Function() fetchMensajes;
  final Future<Map<String, dynamic>> Function(String texto) enviarMensaje;
  final Stream<Map<String, dynamic>> mensajesSocket;

  const ChatThreadScreen({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.threadId,
    required this.idField,
    required this.fetchMensajes,
    required this.enviarMensaje,
    required this.mensajesSocket,
  });

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _errorCarga;
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  StreamSubscription<bool>? _connectionSub;

  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;
  static const Color _bubbleSent = Color(0xFF1A3C6E);
  static const Color _bubbleReceived = Color(0xFFFFFFFF);

  String? get _me => ApiClient.instance.userId?.toString();

  @override
  void initState() {
    super.initState();
    _socketSub = widget.mensajesSocket.listen(_onSocketMessage);
    _connectionSub = SocketServiceClient.instance.onConnection.listen((connected) {
      if (connected && mounted) _fetchMensajes();
    });
    _fetchMensajes();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollCtrl.dispose();
    _socketSub?.cancel();
    _connectionSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchMensajes() async {
    try {
      final msgs = await widget.fetchMensajes();
      if (mounted) {
        setState(() {
          _messages = msgs;
          _loading = false;
          _errorCarga = null;
        });
      }
      _scrollDown();
    } catch (e) {
      if (mounted) setState(() { _loading = false; _errorCarga = mensajeDeError(e); });
    }
  }

  void _reintentar() {
    setState(() { _loading = true; _errorCarga = null; });
    _fetchMensajes();
  }

  void _onSocketMessage(Map<String, dynamic> data) {
    if (!mounted) return;
    if (data[widget.idField]?.toString() != widget.threadId) return;
    final msgId = data['id']?.toString();
    if (msgId != null && _messages.any((m) => m['id']?.toString() == msgId)) return;
    final remitente = data['remitente'] as Map<String, dynamic>?;
    if (remitente != null && remitente['id']?.toString() == _me) return;
    final texto = data['mensaje'] as String?;
    if (texto == null || texto.trim().isEmpty) return;
    setState(() {
      _messages.add({
        'id': msgId,
        'mensaje': texto,
        'remitente': remitente,
        'createdAt': data['createdAt'],
      });
    });
    _scrollDown();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _messages.add({
        'id': tempId,
        'mensaje': text,
        'remitente': {'id': _me},
        'createdAt': DateTime.now().toIso8601String(),
        '_status': 'sending',
      });
    });
    _scrollDown();

    try {
      final saved = await widget.enviarMensaje(text);
      if (mounted) {
        setState(() {
          for (final m in _messages) {
            if (m['id'] == tempId) {
              m['id'] = saved['id']?.toString() ?? tempId;
              m['_status'] = 'sent';
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          for (final m in _messages) {
            if (m['id'] == tempId) m['_status'] = 'failed';
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo enviar el mensaje: ${mensajeDeError(e)}')),
        );
      }
    }
  }

  bool _isMio(Map<String, dynamic> msg) {
    final remitente = msg['remitente'] as Map<String, dynamic>?;
    return remitente?['id']?.toString() == _me;
  }

  String _hora(dynamic ts) {
    final dt = DateTime.tryParse(ts?.toString() ?? '');
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _white,
        foregroundColor: _textDark,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          Text(widget.subtitulo, style: TextStyle(fontSize: 11, color: Colors.green.shade600)),
        ]),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty && _errorCarga != null
                    ? ErrorCarga(
                        titulo: 'No pudimos cargar los mensajes',
                        detalle: _errorCarga,
                        onReintentar: _reintentar,
                      )
                    : _messages.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _buildMessage(_messages[i]),
                      ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('No hay mensajes a\u00fan', style: TextStyle(fontSize: 15, color: Colors.black45)),
          const SizedBox(height: 4),
          Text('Soporte est\u00e1 disponible para ayudarte', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final bool isSent = _isMio(msg);
    final status = msg['_status'] as String?;
    final texto = msg['mensaje'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSent) ...[
            const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFF1A3C6E),
              child: Icon(Icons.support_agent, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment: isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 230),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSent ? _bubbleSent : _bubbleReceived,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isSent ? 16 : 4),
                    bottomRight: Radius.circular(isSent ? 4 : 16),
                  ),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Text(
                  texto,
                  style: TextStyle(color: isSent ? _white : _textDark, fontSize: 14, height: 1.4),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_hora(msg['createdAt']), style: TextStyle(fontSize: 10, color: _textGrey)),
                  const SizedBox(width: 4),
                  if (isSent)
                    Icon(
                      status == 'failed'
                          ? Icons.error_outline
                          : status == 'sending'
                              ? Icons.access_time
                              : Icons.done,
                      size: 14,
                      color: status == 'failed'
                          ? Colors.red
                          : status == 'sending'
                              ? _textGrey
                              : _primaryDark,
                    ),
                ],
              ),
            ],
          ),
          if (isSent) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        color: _white,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                decoration: BoxDecoration(color: _bgLight, borderRadius: BorderRadius.circular(24)),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje...',
                    hintStyle: TextStyle(color: _textGrey, fontSize: 14),
                    isDense: true,
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: 14),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}