import 'package:flutter/material.dart';

class DriverNearbyWarningSheet extends StatelessWidget {
  final VoidCallback? onConfirm;

  const DriverNearbyWarningSheet({super.key, this.onConfirm});

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => DriverNearbyWarningSheet(onConfirm: onConfirm),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 28, 24, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: const Color(0xFFFFF8E1), shape: BoxShape.circle),
            child: const Center(child: Text('\u26a0\ufe0f', style: TextStyle(fontSize: 26))),
          ),
          const SizedBox(height: 18),
          const Text(
            'El conductor ya se encuentra cerca',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E), height: 1.3),
          ),
          const SizedBox(height: 10),
          const Text(
            'Cancelar el viaje podr\u00eda afectar tu\nreputaci\u00f3n.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFF7A7A8C), height: 1.5),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onConfirm?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Entendido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
            ),
          ),
        ],
      ),
    );
  }
}