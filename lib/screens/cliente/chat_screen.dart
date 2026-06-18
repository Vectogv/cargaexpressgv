import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/cache_service.dart';
import '../../services/socket_service_client.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  const ChatScreen({super.key, required this.trip});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _otherTyping = false;
  bool _isTyping = false;
  Timer? _typingTimer;
  Timer? _pollTimer;
  StreamSubscription<Map<String, dynamic>>? _messageSub;
  StreamSubscription<Map<String, dynamic>>? _typingStartSub;
  StreamSubscription<Map<String, dynamic>>? _typingStopSub;
  StreamSubscription<Map<String, dynamic>>? _messageReadSub;
  StreamSubscription<bool>? _connectionSub;

  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;
  static const Color _bubbleSent = Color(0xFF4CAF50);
  static const Color _bubbleReceived = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollCtrl.dispose();
    _typingTimer?.cancel();
    _pollTimer?.cancel();
    _messageSub?.cancel();
    _typingStartSub?.cancel();
    _typingStopSub?.cancel();
    _messageReadSub?.cancel();
    _connectionSub?.cancel();
    super.dispose();
  }

  Future<void> _setup() async {
    _setupSocket();
    final tripId = widget.trip['id']?.toString();
    if (tripId != null) {
      final cached = CacheService.instance.getCachedMessages(tripId);
      if (cached != null && mounted) {
        setState(() { _messages = cached; _loading = false; });
      }
    }
    await _fetchMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _fetchMessages();
    });
  }

  void _setupSocket() {
    final tripId = widget.trip['id']?.toString();
    if (tripId == null) return;

    _messageSub = SocketServiceClient.instance.onMessage.listen((data) {
      if (data['tripId']?.toString() != tripId) return;
      final msgId = data['_id']?.toString() ?? data['id']?.toString();
      if (msgId != null && _messages.any((m) => (m['_id']?.toString() ?? m['id']?.toString()) == msgId)) return;
      final msgText = data['text'] as String? ?? data['mensaje'] as String?;
      final senderId = data['senderId']?.toString();
      final userId = ApiClient.instance.userId;
      if (msgText != null && senderId != userId) {
        setState(() {
          _messages.add({
            '_id': msgId,
            'text': msgText,
            'isSent': false,
            'time': _formatTime(data['timestamp'] ?? data['createdAt']),
          });
        });
        _saveCache();
        _scrollDown();
        _sendReadReceipt(msgId);
      }
    });

    _typingStartSub = SocketServiceClient.instance.onTypingStart.listen((data) {
      if (data['tripId']?.toString() == tripId && mounted) {
        setState(() => _otherTyping = true);
      }
    });

    _typingStopSub = SocketServiceClient.instance.onTypingStop.listen((data) {
      if (data['tripId']?.toString() == tripId && mounted) {
        setState(() => _otherTyping = false);
      }
    });

    _messageReadSub = SocketServiceClient.instance.onMessageRead.listen((data) {
      if (data['tripId']?.toString() != tripId) return;
      final readMsgId = data['messageId']?.toString();
      if (readMsgId == null) return;
      if (mounted) {
        setState(() {
          for (final m in _messages) {
            if ((m['_id']?.toString() ?? m['id']?.toString()) == readMsgId && m['isSent'] == true) {
              m['status'] = 'read';
            }
          }
        });
      }
    });

    _connectionSub = SocketServiceClient.instance.onConnection.listen((connected) {
      if (connected && mounted) _fetchMessages();
    });
  }

  Future<void> _fetchMessages() async {
    try {
      final msgs = await ApiClient.instance.getTripMessages(widget.trip['id']);
      final tripId = widget.trip['id']?.toString();
      if (tripId != null) CacheService.instance.cacheMessages(tripId, msgs);
      if (mounted) {
        setState(() { _messages = msgs; _loading = false; });
        for (final msg in msgs) {
          if (msg['isSent'] != true) {
            _sendReadReceipt(msg['_id'] ?? msg['id']);
          }
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollDown());
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _sendReadReceipt(dynamic msgId) {
    if (msgId == null) return;
    SocketServiceClient.instance.emit('message:read', {
      'tripId': widget.trip['id'],
      'messageId': msgId,
    });
  }

  void _onTyping() {
    if (!_isTyping) {
      _isTyping = true;
      SocketServiceClient.instance.emit('typing:start', {'tripId': widget.trip['id']});
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), _stopTyping);
  }

  void _stopTyping() {
    if (!_isTyping) return;
    _isTyping = false;
    _typingTimer?.cancel();
    SocketServiceClient.instance.emit('typing:stop', {'tripId': widget.trip['id']});
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    _stopTyping();

    final msgId = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _messages.add({'_id': msgId, 'text': text, 'isSent': true, 'time': _now(), 'status': 'sending'});
    });
    _scrollDown();

    SocketServiceClient.instance.emit('message:send', {
      'tripId': widget.trip['id'],
      'text': text,
    });

    try {
      await ApiClient.instance.sendTripMessage(widget.trip['id'], text);
      if (mounted) {
        setState(() {
          for (final m in _messages) {
            if (m['_id'] == msgId) m['status'] = 'sent';
          }
        });
      }
      _saveCache();
    } catch (_) {
      if (mounted) {
        setState(() {
          for (final m in _messages) {
            if (m['_id'] == msgId) m['status'] = 'failed';
          }
        });
      }
    }
  }

  void _saveCache() {
    final tripId = widget.trip['id']?.toString();
    if (tripId != null) {
      CacheService.instance.cacheMessages(tripId, _messages);
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  String _now() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(dynamic ts) {
    final dt = DateTime.tryParse(ts?.toString() ?? '');
    if (dt == null) return _now();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final conductor = widget.trip['conductor'] as Map<String, dynamic>?;
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _textDark,
        elevation: 0,
        title: Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: _primaryDark,
            child: Text(
              _initials(conductor?['nombre'] as String? ?? ''),
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(conductor?['nombre'] as String? ?? 'Conductor', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            Text(_otherTyping ? 'Escribiendo...' : 'En curso', style: TextStyle(fontSize: 11, color: _otherTyping ? Colors.orange.shade600 : Colors.green.shade600)),
          ]),
        ]),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_outlined, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text('No hay mensajes a\u00fan', style: TextStyle(fontSize: 15, color: Colors.black45)),
                            const SizedBox(height: 4),
                            Text('Conversa con tu conductor', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _messages.length + (_otherTyping ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == _messages.length) return _buildTypingIndicator();
                          return _buildMessage(_messages[i]);
                        },
                      ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final bool isSent = msg['isSent'] == true;
    final status = msg['status'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSent) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: _primaryDark.withOpacity(0.2),
              child: Icon(Icons.person, size: 14, color: _primaryDark),
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
                  msg['text'] as String? ?? msg['mensaje'] as String? ?? '',
                  style: TextStyle(color: isSent ? _white : _textDark, fontSize: 14, height: 1.4),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(msg['time'] as String? ?? '', style: TextStyle(fontSize: 10, color: _textGrey)),
                  const SizedBox(width: 4),
                  if (isSent)
                    Icon(
                      status == 'failed' ? Icons.error_outline :
                      status == 'sending' ? Icons.access_time :
                      status == 'read' ? Icons.done_all :
                      Icons.done_all,
                      size: 14,
                      color: status == 'failed' ? Colors.red :
                             status == 'sending' ? _textGrey :
                             status == 'read' ? const Color(0xFF1A3C6E) :
                             const Color(0xFF1A3C6E).withValues(alpha: 0.5),
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

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: _primaryDark.withOpacity(0.2),
            child: Icon(Icons.person, size: 14, color: _primaryDark),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _bubbleReceived,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _dot(0), const SizedBox(width: 4), _dot(1), const SizedBox(width: 4), _dot(2),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _dot(int i) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 600 + i * 200),
      width: 8, height: 8,
      decoration: BoxDecoration(color: _textGrey, shape: BoxShape.circle),
    );
  }

  Widget _buildInputBar() {
    return Container(
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
                onChanged: (_) => _onTyping(),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 42, height: 42,
              decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
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
