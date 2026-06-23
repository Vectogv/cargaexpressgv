import 'dart:math' as math;
import 'package:flutter/material.dart';

class OfertaAceptadaScreen extends StatefulWidget {
  final String conductorNombre;
  final String camion;
  final String placa;
  final double rating;
  final VoidCallback? onVerSeguimiento;

  const OfertaAceptadaScreen({
    super.key,
    required this.conductorNombre,
    required this.camion,
    required this.placa,
    this.rating = 0,
    this.onVerSeguimiento,
  });

  @override
  State<OfertaAceptadaScreen> createState() => _OfertaAceptadaScreenState();
}

class _OfertaAceptadaScreenState extends State<OfertaAceptadaScreen>
    with TickerProviderStateMixin {
  late final AnimationController _checkController;
  late final AnimationController _confettiController;
  late final AnimationController _contentController;

  late final Animation<double> _checkScale;
  late final Animation<double> _checkOpacity;
  late final Animation<double> _contentSlide;
  late final Animation<double> _contentOpacity;

  final List<_ConfettiPiece> _confettiPieces = [];
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < 30; i++) {
      _confettiPieces.add(_ConfettiPiece(
        x: _rng.nextDouble(),
        delay: _rng.nextDouble() * 0.5,
        color: _confettiColors[_rng.nextInt(_confettiColors.length)],
        size: 6 + _rng.nextDouble() * 8,
        angle: _rng.nextDouble() * 2 * math.pi,
        rotSpeed: (_rng.nextDouble() - 0.5) * 4,
        shape: _rng.nextBool() ? _ConfettiShape.circle : _ConfettiShape.rect,
      ));
    }

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.elasticOut),
    );
    _checkOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _contentSlide = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );
    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );

    _checkController.forward().then((_) {
      _confettiController.forward();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _contentController.forward();
      });
    });
  }

  static const _confettiColors = [
    Color(0xFFFF6B6B),
    Color(0xFF4ECDC4),
    Color(0xFFFFE66D),
    Color(0xFFA8E6CF),
    Color(0xFFFF8B94),
    Color(0xFF6C5CE7),
    Color(0xFFFF9F43),
    Color(0xFF00CEC9),
    Color(0xFFFD79A8),
    Color(0xFF55EFC4),
  ];

  @override
  void dispose() {
    _checkController.dispose();
    _confettiController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _confettiController,
                    builder: (_, __) {
                      return CustomPaint(
                        painter: _ConfettiPainter(
                          pieces: _confettiPieces,
                          progress: _confettiController.value,
                        ),
                        child: const SizedBox.expand(),
                      );
                    },
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 32),

                        AnimatedBuilder(
                          animation: _checkController,
                          builder: (_, __) {
                            return Opacity(
                              opacity: _checkOpacity.value,
                              child: Transform.scale(
                                scale: _checkScale.value,
                                child: Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF22C55E),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                                        blurRadius: 24,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 52),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 32),

                        AnimatedBuilder(
                          animation: _contentController,
                          builder: (_, child) {
                            return Opacity(
                              opacity: _contentOpacity.value,
                              child: Transform.translate(
                                offset: Offset(0, _contentSlide.value),
                                child: child,
                              ),
                            );
                          },
                          child: Column(
                            children: [
                              const Text(
                                '\u00a1Oferta aceptada!',
                                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.black87, letterSpacing: -0.5),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.conductorNombre,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ser\u00e1 tu conductor.',
                                style: TextStyle(fontSize: 15, color: Colors.grey[500], fontWeight: FontWeight.w400),
                              ),
                              const SizedBox(height: 28),

                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FA),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFEEEEEE)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.local_shipping_outlined, size: 20, color: Colors.black54),
                                        const SizedBox(width: 10),
                                        Text(
                                          '${widget.camion} \u00b7 ${widget.placa}',
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Icon(Icons.star_rounded, color: Color(0xFFFBBC04), size: 20),
                                        const SizedBox(width: 6),
                                        Text(
                                          widget.rating.toStringAsFixed(1),
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            AnimatedBuilder(
              animation: _contentController,
              builder: (_, child) => Opacity(
                opacity: _contentOpacity.value,
                child: child,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: widget.onVerSeguimiento ?? (() => Navigator.pop(context)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Ver seguimiento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Tu conductor est\u00e1 en camino.', style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w400)),
                    const SizedBox(height: 16),
                    Container(
                      width: 120,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ConfettiShape { circle, rect }

class _ConfettiPiece {
  final double x;
  final double delay;
  final Color color;
  final double size;
  final double angle;
  final double rotSpeed;
  final _ConfettiShape shape;

  const _ConfettiPiece({
    required this.x,
    required this.delay,
    required this.color,
    required this.size,
    required this.angle,
    required this.rotSpeed,
    required this.shape,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double progress;

  const _ConfettiPainter({required this.pieces, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final x = size.width * p.x;
      final y = -p.size + (size.height * 0.75 + p.size) * t;
      final opacity = t < 0.7 ? 1.0 : (1.0 - (t - 0.7) / 0.3);
      final rot = p.angle + p.rotSpeed * t * math.pi;

      final paint = Paint()..color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);

      if (p.shape == _ConfettiShape.circle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
            const Radius.circular(2),
          ),
          paint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}