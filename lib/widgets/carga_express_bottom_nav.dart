import 'package:flutter/material.dart';

import '../screens/shared/ui_compartida.dart';

/// Barra inferior de 4 pestañas: blanca, con borde superior y sin sombra.
class CargaExpressBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<({IconData icon, String label, VoidCallback onTap})> items;

  const CargaExpressBottomNav({
    super.key,
    required this.currentIndex,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColoresApp.borde)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: List.generate(items.length, (i) {
              final isActive = i == currentIndex;
              final color = isActive ? ColoresApp.azul : ColoresApp.textoSecundario;
              return Expanded(
                child: GestureDetector(
                  onTap: items[i].onTap,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(items[i].icon, color: color, size: 22),
                      const SizedBox(height: 4),
                      Text(
                        items[i].label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
