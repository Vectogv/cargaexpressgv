import 'package:flutter/material.dart';

class TripChatScreen extends StatefulWidget {
  const TripChatScreen({super.key});

  @override
  State<TripChatScreen> createState() => _TripChatScreenState();
}

class _TripChatScreenState extends State<TripChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;
  static const Color _bubbleSent = Color(0xFF1565C0);
  static const Color _bubbleReceived = Color(0xFFFFFFFF);

  final List<Map<String, dynamic>> _messages = [
    {
      'text': 'Hola Juan, ¿a qué hora puedes recoger la carga?',
      'isSent': false,
      'time': '10:00 AM',
    },
    {
      'text': 'Hola, estoy en camino. Llegaré a las 11:00 AM.',
      'isSent': true,
      'time': '10:22 AM',
    },
    {
      'text': 'Perfecto, te espero.',
      'isSent': false,
      'time': '10:32 AM',
    },
    {
      'text': 'Carga recogida ✅\nTodo en orden.',
      'isSent': true,
      'time': '11:54 AM',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) =>
                  _buildMessage(_messages[index]),
            ),
          ),
          _buildInputBar(),
          _buildBottomNav(context),
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
                const Text(
                  'Chat del viaje',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                Text(
                  'ID: #4821',
                  style:
                      TextStyle(fontSize: 12, color: _textGrey),
                ),
              ],
            ),
          ),
          const Icon(Icons.more_vert, size: 24),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final bool isSent = msg['isSent'] as bool;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSent) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: const NetworkImage(
                  'https://randomuser.me/api/portraits/men/45.jpg'),
            ),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment:
                isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 230),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSent ? _bubbleSent : _bubbleReceived,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isSent ? 16 : 4),
                    bottomRight: Radius.circular(isSent ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  msg['text'],
                  style: TextStyle(
                    color: isSent ? _white : _textDark,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    msg['time'],
                    style: TextStyle(fontSize: 10, color: _textGrey),
                  ),
                  if (isSent) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.done_all,
                        size: 14, color: _primaryDark),
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
              decoration: BoxDecoration(
                color: _bgLight,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  hintStyle: TextStyle(color: _textGrey, fontSize: 14),
                  isDense: true,
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _primaryDark,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.send_rounded, color: _white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      color: _white,
      padding: const EdgeInsets.only(bottom: 20, top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_rounded, 'Inicio', false),
          _navItem(Icons.local_shipping_outlined, 'Viajes', false),
          _navItem(Icons.local_offer_outlined, 'Ofertas', false),
          _navItem(Icons.chat_bubble_rounded, 'Chat', true),
          _navItem(Icons.person_outline, 'Perfil', false),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            color: isActive ? _primaryDark : _textGrey, size: 24),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? _primaryDark : _textGrey,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        if (isActive)
          Container(
            margin: const EdgeInsets.only(top: 3),
            width: 5,
            height: 5,
            decoration:
                BoxDecoration(color: _primaryDark, shape: BoxShape.circle),
          ),
      ],
    );
  }
}
