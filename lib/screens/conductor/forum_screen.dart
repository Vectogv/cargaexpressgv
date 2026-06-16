import 'package:flutter/material.dart';
import '../../services/api_client.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;

  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    try {
      final posts = await ApiClient.instance.getForumPosts();
      if (mounted) setState(() { _posts = posts; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createPost() async {
    final textCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva publicación'),
        content: TextField(
          controller: textCtrl,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Escribe tu mensaje...', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _primaryDark),
            child: const Text('Publicar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result != true || textCtrl.text.trim().isEmpty) return;
    try {
      await ApiClient.instance.createForumPost({'contenido': textCtrl.text.trim()});
      _fetchPosts();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')));
    }
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
                : _posts.isEmpty
                    ? const Center(child: Text('No hay publicaciones aún', style: TextStyle(color: Colors.black45)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _posts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _buildPostCard(_posts[i]),
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
          const Text('Foro', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(14), boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
      ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _primaryDark.withOpacity(0.15),
                child: Text(
                  _initials(post['autor']?['nombre'] as String? ?? ''),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _primaryDark),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post['autor']?['nombre'] as String? ?? 'Anónimo', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(_formatDate(post['createdAt'] as String?), style: TextStyle(fontSize: 11, color: _textGrey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(post['contenido'] as String? ?? post['text'] as String? ?? '', style: TextStyle(fontSize: 14, color: _textDark, height: 1.5)),
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
          onPressed: _createPost,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryDark,
            foregroundColor: _white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: const Text('Publicar en el foro', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}