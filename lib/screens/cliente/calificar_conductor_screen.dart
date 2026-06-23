import 'package:flutter/material.dart';
import '../../services/api_client.dart';

class CalificarConductorScreen extends StatefulWidget {
  final Map<String, dynamic> conductor;
  final dynamic tripId;
  final VoidCallback onSubmitted;

  const CalificarConductorScreen({
    super.key,
    required this.conductor,
    required this.tripId,
    required this.onSubmitted,
  });

  @override
  State<CalificarConductorScreen> createState() => _CalificarConductorScreenState();
}

class _CalificarConductorScreenState extends State<CalificarConductorScreen> {
  int _rating = 0;
  bool _submitting = false;
  final TextEditingController _commentController = TextEditingController();

  static const _labels = ['Malo', 'Regular', 'Bueno', 'Muy bueno', 'Excelente'];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.conductor['nombre'] as String? ?? 'Conductor';
    final ratingActual = (widget.conductor['rating'] as num?)?.toStringAsFixed(1) ?? '0.0';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        centerTitle: true,
        title: const Text(
          'Califica a tu conductor',
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE5E7EB),
                      border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
                    ),
                    child: const ClipOval(
                      child: Icon(Icons.person, size: 36, color: Color(0xFF9CA3AF)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Color(0xFFFBBF24), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            ratingActual,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                '\u00bfC\u00f3mo fue tu experiencia?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final selected = i < _rating;
                  return GestureDetector(
                    onTap: () => setState(() => _rating = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        selected ? Icons.star : Icons.star_border,
                        color: selected ? const Color(0xFFFBBF24) : const Color(0xFFD1D5DB),
                        size: 42,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              Text(
                _rating > 0 ? _labels[_rating - 1] : '',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _commentController,
                maxLines: 4,
                minLines: 3,
                style: const TextStyle(fontSize: 14, color: Colors.black),
                decoration: InputDecoration(
                  hintText: 'Escribe un comentario (opcional)',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting
                      ? null
                      : () async {
                          setState(() => _submitting = true);
                          try {
                            await ApiClient.instance.rateTrip(
                              widget.tripId,
                              _rating,
                              comentario: _commentController.text,
                            );
                            if (!mounted) return;
                            Navigator.of(context).popUntil((route) => route.isFirst);
                            widget.onSubmitted();
                          } catch (e) {
                            if (!mounted) return;
                            setState(() => _submitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    disabledBackgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.45),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text(
                          'Enviar calificaci\u00f3n',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
