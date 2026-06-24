import 'package:flutter/material.dart';

class MiVersionScreen extends StatefulWidget {
  final String? initialDescripcion;
  final void Function(String descripcion)? onSubmit;
  final VoidCallback? onPickMedia;
  final List<Widget>? mediaThumbnails;

  const MiVersionScreen({
    super.key,
    this.initialDescripcion,
    this.onSubmit,
    this.onPickMedia,
    this.mediaThumbnails,
  });

  @override
  State<MiVersionScreen> createState() => _MiVersionScreenState();
}

class _MiVersionScreenState extends State<MiVersionScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialDescripcion ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const Color _textPrimary = Color(0xFF111111);
  static const Color _textBody = Color(0xFF333333);
  static const Color _hint = Color(0xFFAAAAAA);
  static const Color _blue = Color(0xFF1565C0);
  static const Color _inputBorder = Color(0xFFDDDDDD);
  static const Color _addIcon = Color(0xFF888888);
  static const Color _addBorder = Color(0xFFCCCCCC);
  static const Color _divider = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Mi versión',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: _textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Describe tu versión de los hechos',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _inputBorder, width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _controller,
                        maxLines: 6,
                        style: const TextStyle(
                          fontSize: 14,
                          color: _textBody,
                          height: 1.55,
                        ),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.all(14),
                          border: InputBorder.none,
                          hintText: 'Escribe tu versión aquí...',
                          hintStyle: TextStyle(color: _hint),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Fotos / Videos (opcional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (widget.mediaThumbnails != null)
                          ...widget.mediaThumbnails!,
                        GestureDetector(
                          onTap: widget.onPickMedia,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                  color: widget.onPickMedia == null ? _divider : _addBorder, width: 1.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.add,
                              size: 28,
                              color: widget.onPickMedia == null
                                  ? _divider
                                  : _addIcon,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: widget.onSubmit == null
                      ? null
                      : () => widget.onSubmit!(_controller.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    disabledBackgroundColor: _divider,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Enviar evidencia',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
