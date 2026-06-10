import 'package:flutter/material.dart';

class ForumScreen extends StatelessWidget {
  const ForumScreen({super.key});

  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;

  final List<Map<String, dynamic>> _posts = const [
    {
      'name': 'Carlos M.',
      'avatar': 'https://randomuser.me/api/portraits/men/11.jpg',
      'time': 'Hace 2 horas',
      'text':
          '¿Alguien ha tenido problemas con la empresa XYZ? Compartan sus experiencias.',
      'likes': 12,
      'comments': 8,
    },
    {
      'name': 'Andrés T.',
      'avatar': 'https://randomuser.me/api/portraits/men/22.jpg',
      'time': 'Hace 1 hora',
      'text':
          'Recomiendo el parqueadero seguro en Girardot, muy buen servicio.',
      'likes': 7,
      'comments': 3,
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
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _posts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _buildPostCard(_posts[index]),
            ),
          ),
          _buildPublishButton(),
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
          const Text('Foro - Zona Norte',
              style:
                  TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(post['avatar']),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post['name'],
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Text(post['time'],
                        style: TextStyle(
                            fontSize: 11, color: _textGrey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post['text'],
            style: TextStyle(
                fontSize: 14, color: _textDark, height: 1.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.thumb_up_outlined,
                  size: 18, color: _textGrey),
              const SizedBox(width: 4),
              Text('${post['likes']}',
                  style: TextStyle(fontSize: 13, color: _textGrey)),
              const SizedBox(width: 16),
              Icon(Icons.chat_bubble_outline,
                  size: 18, color: _textGrey),
              const SizedBox(width: 4),
              Text('${post['comments']}',
                  style: TextStyle(fontSize: 13, color: _textGrey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPublishButton() {
    return Container(
      color: _white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryDark,
            foregroundColor: _white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: const Text('Publicar en el foro',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }


}
