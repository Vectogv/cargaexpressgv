import 'package:flutter/material.dart';

class CancelTripScreen extends StatefulWidget {
  final bool enCurso;

  const CancelTripScreen({super.key, this.enCurso = false});

  @override
  State<CancelTripScreen> createState() => _CancelTripScreenState();
}

class _CancelTripScreenState extends State<CancelTripScreen> {
  static const _reasons = [
    'Cambi\u00e9 de opini\u00f3n',
    'Error en la direcci\u00f3n',
    'Consegu\u00ed otro transporte',
    'Demora excesiva del conductor',
    'Otro motivo',
  ];

  static const _reasonsEnCurso = [
    'Conductor no se present\u00f3',
    'Demora excesiva',
    'Problema con la carga',
    'Emergencia personal',
    'Otro motivo',
  ];

  List<String> get _reasonsList => widget.enCurso ? _reasonsEnCurso : _reasons;

  String? _selected;
  final _commentController = TextEditingController();

  void _confirm() {
    final reason = _selected;
    if (reason == null) return;
    Navigator.pop(context, {
      'reason': reason,
      'comment': _commentController.text.trim(),
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Cancelar viaje',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              widget.enCurso
                  ? 'El viaje est\u00e1 en curso. Se notificar\u00e1 al administrador.'
                  : '\u00bfPor qu\u00e9 deseas cancelar este viaje?',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 20),

            ...List.generate(_reasonsList.length, (i) {
              final reason = _reasonsList[i];
              final isSelected = _selected == reason;
              return GestureDetector(
                onTap: () => setState(() => _selected = reason),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    children: [
                      _CustomRadio(selected: isSelected),
                      const SizedBox(width: 14),
                      Text(
                        reason,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? const Color(0xFF1A1A2E) : const Color(0xFF4A4A5A),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),

            TextField(
              controller: _commentController,
              maxLines: 4,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
              decoration: InputDecoration(
                hintText: 'Escribe un comentario (opcional)',
                hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFB0B0C0)),
                filled: true,
                fillColor: const Color(0xFFF8F9FB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE8E8EF)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE8E8EF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2D9CDB), width: 1.5),
                ),
              ),
            ),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFDDDDE8), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.white,
                      ),
                      child: const Text(
                        'No cancelar',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selected == null ? null : _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        disabledBackgroundColor: const Color(0xFFE53935).withValues(alpha: 0.45),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Confirmar cancelaci\u00f3n',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomRadio extends StatelessWidget {
  final bool selected;
  const _CustomRadio({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? const Color(0xFFE53935) : const Color(0xFFCCCCD8),
          width: selected ? 0 : 1.5,
        ),
        color: selected ? const Color(0xFFE53935) : Colors.transparent,
      ),
      child: selected
          ? const Center(child: Icon(Icons.circle, color: Colors.white, size: 10))
          : null,
    );
  }
}