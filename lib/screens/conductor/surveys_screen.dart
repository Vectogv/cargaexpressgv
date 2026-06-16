import 'package:flutter/material.dart';
import '../../services/api_client.dart';

class SurveysScreen extends StatefulWidget {
  const SurveysScreen({super.key});

  @override
  State<SurveysScreen> createState() => _SurveysScreenState();
}

class _SurveysScreenState extends State<SurveysScreen> {
  final List<Map<String, dynamic>> _surveys = [];
  bool _loading = true;

  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;

  @override
  void initState() {
    super.initState();
    _fetchSurveys();
  }

  Future<void> _fetchSurveys() async {
    // Las encuestas se gestionan desde el panel moderador.
    // El conductor responde mediante enlaces directos.
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _answerSurvey(String id, dynamic opcionId) async {
    try {
      await ApiClient.instance.answerSurvey(id, opcionId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Respuesta registrada')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')));
    }
  }

  Future<void> _showResults(String id) async {
    try {
      final result = await ApiClient.instance.getSurveyResults(id);
      if (!mounted) return;
      final opciones = result['opciones'] as List? ?? [];
      final total = (result['totalVotos'] as num?)?.toDouble() ?? 1;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(result['titulo'] as String? ?? 'Resultados'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: opciones.map<Widget>((o) {
              final votos = (o['votos'] as num?)?.toDouble() ?? 0;
              final pct = total > 0 ? (votos / total * 100) : 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(o['texto'] as String? ?? o['text'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                        Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        backgroundColor: Colors.grey.shade200,
                        color: _primaryDark,
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          ],
        ),
      );
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
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.poll_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('Encuestas', style: TextStyle(fontSize: 16, color: Colors.black45)),
                        const SizedBox(height: 6),
                        const Text('Las encuestas son gestionadas por moderadores', style: TextStyle(fontSize: 13, color: Colors.black38)),
                      ],
                    ),
                  ),
          ),
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
          const Text('Encuestas', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}