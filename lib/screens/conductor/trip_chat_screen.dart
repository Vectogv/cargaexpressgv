import 'package:flutter/material.dart';
import '../../services/api_client.dart';

class TripChatScreen extends StatefulWidget {
  final Map<String, dynamic>? trip;
  const TripChatScreen({super.key, this.trip});

  @override
  State<TripChatScreen> createState() => _TripChatScreenState();
}

class _TripChatScreenState extends State<TripChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  Map<String, dynamic>? _activeTrip;
  bool _canChat = false;

  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;
  static const Color _bubbleSent = Color(0xFF1565C0);
  static const Color _bubbleReceived = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _initTrip();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _initTrip() async {
    try {
      if (widget.trip != null) {
        _activeTrip = widget.trip;
      } else {
        _activeTrip = await ApiClient.instance.getActiveTrip();
      }
      final estado = _activeTrip?['estado'] as String?;
      _canChat = estado == 'en_curso';
      if (_canChat) {
        await _fetchMessages();
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchMessages() async {
    if (_activeTrip == null) return;
    try {
      final msgs = await ApiClient.instance.getTripMessages(_activeTrip!['id']);
      if (mounted) setState(() { _messages = msgs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _activeTrip == null) return;
    _messageController.clear();
    setState(() => _messages.add({'text': text, 'isSent': true, 'time': _now()}));
    try {
      await ApiClient.instance.sendTripMessage(_activeTrip!['id'], text);
      _fetchMessages();
    } catch (_) {}
  }

  String _now() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : !_canChat
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text('Chat no disponible', style: TextStyle(fontSize: 16, color: Colors.black45)),
                            const SizedBox(height: 6),
                            const Text('El chat está disponible solo durante viajes en curso', style: TextStyle(fontSize: 13, color: Colors.black38)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _buildMessage(_messages[i]),
                      ),
          ),
          if (_canChat) _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _white,
      padding: const EdgeInsets.only(top: 44, left: 16, right: 16, bottom: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chat del viaje', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                if (_activeTrip != null)
                  Text('ID: ${_activeTrip!['id']}', style: TextStyle(fontSize: 12, color: _textGrey)),
              ],
            ),
          ),
          if (_canChat)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF4CAF50).withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: const Text('En curso', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4CAF50))),
            ),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final bool isSent = msg['isSent'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSent) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: _primaryDark.withOpacity(0.2),
              child: Text(
                _initials(_activeTrip?['cliente']?['nombre'] as String? ?? '?'),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
              ),
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
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Text(
                  msg['text'] as String? ?? '',
                  style: TextStyle(color: isSent ? _white : _textDark, fontSize: 14, height: 1.4),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(msg['time'] as String? ?? '', style: TextStyle(fontSize: 10, color: _textGrey)),
                  if (isSent) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.done_all, size: 14, color: Color(0xFF1A3C6E)),
                  ],
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
    return Container(
      color: _white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Icon(Icons.attach_file_outlined, color: _textGrey, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              decoration: const BoxDecoration(color: Color(0xFF1A3C6E), shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }
}