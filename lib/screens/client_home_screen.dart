import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  final _origenCtrl = TextEditingController();
  final _destinoCtrl = TextEditingController();
  bool _solicitando = false;
  bool _matched = false;

  static const _centerPos = LatLng(10.4806, -66.9036);

  final _conductores = <_ConductorSimulado>[
    _ConductorSimulado(LatLng(10.485, -66.895), 'Carlos M.', 4.9, 'ABC-123'),
    _ConductorSimulado(LatLng(10.475, -66.910), 'Luis R.', 4.8, 'DEF-456'),
    _ConductorSimulado(LatLng(10.490, -66.905), 'José P.', 4.9, 'GHI-789'),
  ];

  Timer? _matchTimer;

  @override
  void dispose() {
    _origenCtrl.dispose();
    _destinoCtrl.dispose();
    _matchTimer?.cancel();
    super.dispose();
  }

  void _solicitarViaje() {
    setState(() => _solicitando = true);
    _matchTimer = Timer(Duration(seconds: 3), () {
      if (mounted) setState(() => _matched = true);
    });
  }

  void _cancelar() {
    _matchTimer?.cancel();
    setState(() {
      _solicitando = false;
      _matched = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          _buildTopBar(),
          _buildBottomSheet(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      options: MapOptions(initialCenter: _centerPos, initialZoom: 15),
      children: [
        TileLayer(
          urlTemplate:
              'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.cargaexpress.app',
        ),
        MarkerLayer(
          markers: _conductores.map((c) {
            final isClosest = !_solicitando;
            return Marker(
              point: c.pos,
              width: 80,
              height: 80,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isClosest)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${c.rating} ⭐',
                          style: TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  if (isClosest) SizedBox(height: 2),
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Color(0xFF1A8CFF),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                    child: Icon(Icons.local_shipping, color: Colors.white, size: 18),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        if (_matched)
          MarkerLayer(
            markers: [
              Marker(
                point: _centerPos,
                width: 100,
                height: 100,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('¡En camino!',
                          style: TextStyle(color: Colors.white, fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(height: 4),
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(
                            color: Colors.green.withValues(alpha: 0.5),
                            blurRadius: 10)],
                      ),
                      child: Icon(Icons.navigation, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.menu_rounded, color: Colors.white, size: 22),
              ),
              Spacer(),
              Text('CargaExpress',
                  style: TextStyle(color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.bold)),
              Spacer(),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person_outline, color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheet() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFF0D0D0D),
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28), topRight: Radius.circular(28)),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30, offset: Offset(0, -10))],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4))),
              SizedBox(height: 20),
              if (!_solicitando && !_matched)
                _buildForm()
              else if (_solicitando && !_matched)
                _buildBuscando()
              else
                _buildMatched(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¿A dónde vas?',
            style: TextStyle(color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.bold)),
        SizedBox(height: 20),
        _buildDireccionField(
          controller: _origenCtrl,
          hint: 'Tu ubicación',
          icon: Icons.circle,
          iconColor: Color(0xFF1A8CFF),
          readOnly: true,
          value: 'Av. Principal, Los Palos Grandes',
        ),
        SizedBox(height: 12),
        _buildDireccionField(
          controller: _destinoCtrl,
          hint: '¿A dónde va la carga?',
          icon: Icons.square,
          iconColor: Colors.white.withValues(alpha: 0.4),
        ),
        SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 54,
          child: ElevatedButton(
            onPressed: _destinoCtrl.text.isNotEmpty ? _solicitarViaje : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF1A8CFF),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
              disabledForegroundColor: Colors.white.withValues(alpha: 0.2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: Color(0xFF1A8CFF).withValues(alpha: 0.4),
            ),
            child: Text('Solicitar envío',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildDireccionField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
    bool readOnly = false,
    String? value,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: value ?? hint,
                hintStyle: TextStyle(
                    color: value != null
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                    fontSize: 15),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuscando() {
    return Column(
      children: [
        SizedBox(height: 8),
        SizedBox(
          width: 72, height: 72,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(Color(0xFF1A8CFF)),
          ),
        ),
        SizedBox(height: 16),
        Text('Buscando conductor...',
            style: TextStyle(color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.w600)),
        Text('Estamos buscando un conductor disponible',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13)),
        SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _cancelar,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
              elevation: 0,
            ),
            child: Text('Cancelar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildMatched() {
    return Column(
      children: [
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: Colors.green, shape: BoxShape.circle)),
              SizedBox(width: 6),
              Text('CONDUCTOR ASIGNADO',
                  style: TextStyle(color: Colors.green, fontSize: 11,
                      fontWeight: FontWeight.w700, letterSpacing: 1)),
            ],
          ),
        ),
        SizedBox(height: 20),
        Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: Color(0xFF1A8CFF).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Color(0xFF1A8CFF).withValues(alpha: 0.3), width: 2),
              ),
              child: Center(child: Text('CM',
                  style: TextStyle(color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.bold))),
            ),
            SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Carlos Mendoza',
                    style: TextStyle(color: Colors.white, fontSize: 17,
                        fontWeight: FontWeight.bold)),
                Text('ABC-123 · 4.9 ⭐ · Llega en 5 min',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13)),
              ],
            )),
          ],
        ),
        SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildContactBtn(Icons.phone_rounded, 'Llamar'),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildContactBtn(Icons.chat_rounded, 'Mensaje'),
            ),
          ],
        ),
        SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _cancelar,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text('Cancelar viaje',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildContactBtn(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 18),
          SizedBox(width: 8),
          Text(label, style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7), fontSize: 14,
              fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ConductorSimulado {
  final LatLng pos;
  final String name;
  final double rating;
  final String placa;
  const _ConductorSimulado(this.pos, this.name, this.rating, this.placa);
}
