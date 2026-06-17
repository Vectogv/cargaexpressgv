import 'package:flutter/material.dart';

class PagosScreen extends StatefulWidget {
  const PagosScreen({super.key});

  @override
  State<PagosScreen> createState() => _PagosScreenState();
}

class _PagosScreenState extends State<PagosScreen> {
  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Pagos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('M\u00e9todos de pago', [
            _buildMethodCard(Icons.credit_card, 'Tarjeta de cr\u00e9dito/d\u00e9bito', 'Visa **** 4242'),
            _buildMethodCard(Icons.account_balance_wallet, 'Efectivo', 'Pago al conductor'),
          ]),
          const SizedBox(height: 16),
          _buildSection('Historial de pagos', [
            _buildPlaceholder('Pr\u00f3ximamente podr\u00e1s ver tu historial de pagos'),
          ]),
          const SizedBox(height: 16),
          _buildSection('Facturas y comprobantes', [
            _buildPlaceholder('Pr\u00f3ximamente podr\u00e1s descargar tus facturas'),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textGrey)),
        ),
        Container(
          decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(14)),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildMethodCard(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: _primaryDark.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 22, color: _primaryDark),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: _textGrey)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {},
    );
  }

  Widget _buildPlaceholder(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Text(text, style: const TextStyle(color: _textGrey, fontSize: 13), textAlign: TextAlign.center),
    );
  }
}
