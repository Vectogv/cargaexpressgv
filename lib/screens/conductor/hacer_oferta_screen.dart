import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_client.dart';

class HacerOfertaScreen extends StatefulWidget {
  final dynamic tripId;
  final String precioCliente;
  final double ofertaInicial;
  final String? placa;

  const HacerOfertaScreen({
    super.key,
    required this.tripId,
    this.precioCliente = '\$50.000',
    this.ofertaInicial = 55000,
    this.placa,
  });

  @override
  State<HacerOfertaScreen> createState() => _HacerOfertaScreenState();
}

class _HacerOfertaScreenState extends State<HacerOfertaScreen> {
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _green = Color(0xFF16A34A);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _divider = Color(0xFFE5E7EB);
  static const Color _inputBorder = Color(0xFFD1D5DB);
  static const Color _chipBg = Color(0xFFEFF6FF);
  static const Color _chipBorder = Color(0xFFBFDBFE);

  late double _ofertaActual;
  late TextEditingController _controller;
  final TextEditingController _mensajeController = TextEditingController();
  final FocusNode _ofertaFocus = FocusNode();
  bool _sending = false;

  final List<double> _incrementos = [2000, 5000, 10000];

  @override
  void initState() {
    super.initState();
    _ofertaActual = widget.ofertaInicial;
    _controller = TextEditingController(text: _formatValue(_ofertaActual));
  }

  @override
  void dispose() {
    _controller.dispose();
    _mensajeController.dispose();
    _ofertaFocus.dispose();
    super.dispose();
  }

  String _formatValue(double value) {
    final int v = value.toInt();
    final String s = v.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return '\$${buffer.toString()}';
  }

  void _aplicarIncremento(double incremento) {
    setState(() {
      _ofertaActual += incremento;
      _controller.text = _formatValue(_ofertaActual);
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    });
  }

  void _onOfertaChanged(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      _ofertaActual = 0;
      return;
    }
    _ofertaActual = double.parse(digits);
  }

  Future<void> _enviarOferta() async {
    final monto = _ofertaActual.toInt();
    if (monto <= 0) {
      _snack('Ingresa un monto válido');
      return;
    }
    setState(() => _sending = true);
    try {
      await ApiClient.instance.makeOffer(widget.tripId, monto, placa: widget.placa);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPriceClienteCard(),
                    const SizedBox(height: 24),
                    _buildMiOfertaSection(),
                    const SizedBox(height: 20),
                    _buildMensajeSection(),
                    const SizedBox(height: 20),
                    _buildInfoNotes(),
                  ],
                ),
              ),
            ),
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        'Hacer oferta',
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

  Widget _buildPriceClienteCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 14, color: _textSecondary),
              const SizedBox(width: 5),
              const Text(
                'Precio propuesto por el cliente',
                style: TextStyle(fontSize: 12, color: _textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.precioCliente,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiOfertaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mi oferta',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _controller,
          focusNode: _ofertaFocus,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: _onOfertaChanged,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
          decoration: InputDecoration(
            prefixText: '\$',
            prefixStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _accentBlue, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: _incrementos.map((inc) {
            final label =
                '+ \$${inc >= 1000 ? '${(inc / 1000).toStringAsFixed(0)}.000' : inc.toStringAsFixed(0)}';
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    right: inc != _incrementos.last ? 8 : 0),
                child: GestureDetector(
                  onTap: () => _aplicarIncremento(inc),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _chipBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _chipBorder),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: _accentBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMensajeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mensaje (opcional)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _mensajeController,
          maxLines: 4,
          minLines: 4,
          textInputAction: TextInputAction.newline,
          style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
          decoration: InputDecoration(
            hintText: 'Escribe un mensaje al cliente...',
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
        ),
      ],
    );
  }

  Widget _buildInfoNotes() {
    const notes = [
      'Tu oferta será enviada al cliente',
      'Podrás ver la respuesta en tu bandeja',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: notes
          .map(
            (note) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ',
                      style:
                          TextStyle(color: _textSecondary, fontSize: 13)),
                  Expanded(
                    child: Text(
                      note,
                      style: const TextStyle(
                          color: _textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _sending ? null : () => Navigator.of(context).maybePop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: const BorderSide(color: _inputBorder, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Cancelar',
                style: TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _sending ? null : _enviarOferta,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentBlue,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: _sending
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text(
                      'Enviar oferta',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
