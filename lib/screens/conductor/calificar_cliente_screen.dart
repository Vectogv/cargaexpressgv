import 'package:flutter/material.dart';

class CalificarClienteScreen extends StatefulWidget {
  final String nombreCliente;
  final double ratingActual;
  final String? avatarUrl;
  final void Function(int estrellas, String comentario)? onEnviar;

  const CalificarClienteScreen({
    super.key,
    this.nombreCliente = 'Maria González',
    this.ratingActual = 4.8,
    this.avatarUrl,
    this.onEnviar,
  });

  @override
  State<CalificarClienteScreen> createState() => _CalificarClienteScreenState();
}

class _CalificarClienteScreenState extends State<CalificarClienteScreen> {
  int _estrellas = 5;
  final TextEditingController _comentarioCtrl = TextEditingController();

  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _star = Color(0xFFF59E0B);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _divider = Color(0xFFE5E7EB);
  static const Color _inputBorder = Color(0xFFD1D5DB);
  static const Color _greenDark = Color(0xFF15803D);

  static const List<String> _labels = [
    '', 'Malo', 'Regular', 'Bueno', 'Muy bueno', 'Excelente'
  ];

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  children: [
                    _buildClienteCard(),
                    const SizedBox(height: 28),
                    _buildEstrellasSection(),
                    const SizedBox(height: 24),
                    _buildComentario(),
                  ],
                ),
              ),
            ),
            _buildBotonEnviar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        'Califica a tu cliente',
        style: TextStyle(
          color: Color(0xFF111827),
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF111827), size: 20),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }

  Widget _buildClienteCard() {
    final parts = widget.nombreCliente.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : parts[0][0].toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFD1FAE5),
            backgroundImage: widget.avatarUrl != null
                ? NetworkImage(widget.avatarUrl!)
                : null,
            child: widget.avatarUrl == null
                ? Text(initials,
                    style: const TextStyle(
                        color: _greenDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 17))
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.nombreCliente,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: _star, size: 17),
                    const SizedBox(width: 4),
                    Text(widget.ratingActual.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstrellasSection() {
    return Column(
      children: [
        const Text(
          '¿Cómo fue tu experiencia?',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _textPrimary),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final filled = i < _estrellas;
            return GestureDetector(
              onTap: () => setState(() => _estrellas = i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: filled ? _star : const Color(0xFFD1D5DB),
                  size: 44,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _labels[_estrellas],
            key: ValueKey(_estrellas),
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildComentario() {
    return TextField(
      controller: _comentarioCtrl,
      maxLines: 4,
      minLines: 3,
      style: const TextStyle(fontSize: 14, color: _textPrimary),
      decoration: InputDecoration(
        hintText: 'Escribe un comentario (opcional)',
        hintStyle: const TextStyle(color: _textSecondary, fontSize: 14),
        contentPadding: const EdgeInsets.all(14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _accentBlue, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildBotonEnviar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: widget.onEnviar == null
              ? null
              : () => widget.onEnviar!(_estrellas, _comentarioCtrl.text.trim()),
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentBlue,
            disabledBackgroundColor: _divider,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text(
            'Enviar calificación',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
