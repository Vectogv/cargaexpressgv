import 'package:flutter/material.dart';

class BuscandoConductoresScreen extends StatefulWidget {
  const BuscandoConductoresScreen({super.key});

  @override
  State<BuscandoConductoresScreen> createState() =>
      _BuscandoConductoresScreenState();
}

class _BuscandoConductoresScreenState extends State<BuscandoConductoresScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Buscando conductor',
          style: TextStyle(color: Color(0xFF1A1A2E)),
        ),
      ),
      body: Column(
        children: [
          const Spacer(),
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: List.generate(
                3,
                (i) => _PulseCircle(
                  controller: _controller,
                  index: i,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Buscando conductor disponible...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Por favor espera mientras encontramos un conductor cerca de ti.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Cancelar b\u00fasqueda',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseCircle extends StatelessWidget {
  final AnimationController controller;
  final int index;

  const _PulseCircle({
    required this.controller,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final double t = controller.value;
        final double start = index * 0.33;
        final double end = (start + 0.67).clamp(0.0, 1.0);
        final double localT = ((t - start) / (end - start)).clamp(0.0, 1.0);
        final double scale = 0.6 + localT * 1.4;
        final double opacity = (1.0 - localT).clamp(0.0, 1.0);

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
        );
      },
    );
  }
}
