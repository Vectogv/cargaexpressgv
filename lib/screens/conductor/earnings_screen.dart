import 'package:flutter/material.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildEarningsCard(),
                  const SizedBox(height: 12),
                  _buildHistoryItem(),
                  const SizedBox(height: 10),
                  _buildDebtItem(),
                  const SizedBox(height: 10),
                  _buildUploadItem(),
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
          const Text(
            'Ganancias',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total ganado (este mes)',
            style: TextStyle(
              fontSize: 13,
              color: _textGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$2.450.000',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: _primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.trending_up, color: _accentGreen, size: 16),
              const SizedBox(width: 4),
              Text(
                '+12% vs mes anterior',
                style: TextStyle(
                  fontSize: 13,
                  color: _accentGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem() {
    return _buildMenuCard(
      icon: Icons.bar_chart_outlined,
      iconBg: const Color(0xFFE3F2FD),
      iconColor: const Color(0xFF1565C0),
      title: 'Historial de ganancias',
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
    );
  }

  Widget _buildDebtItem() {
    return _buildMenuCard(
      icon: Icons.account_balance_wallet_outlined,
      iconBg: const Color(0xFFFCE4EC),
      iconColor: Colors.red.shade700,
      title: 'Deuda de comisión',
      trailing: Text(
        '\$120.000',
        style: TextStyle(
          color: Colors.red.shade700,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildUploadItem() {
    return _buildMenuCard(
      icon: Icons.upload_file_outlined,
      iconBg: const Color(0xFFE8F5E9),
      iconColor: const Color(0xFF2E7D32),
      title: 'Subir comprobante de pago',
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          trailing,
        ],
      ),
    );
  }

}
