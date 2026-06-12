import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../user/auth_screen.dart';
import 'nuevo_envio_screen.dart';
import 'mis_envios_screen.dart';
import 'rastreo_screen.dart';
import 'perfil_screen.dart';
import '../conductor/notifications_screen.dart';

class ClienteHomeScreen extends StatefulWidget {
  const ClienteHomeScreen({super.key});

  @override
  State<ClienteHomeScreen> createState() => _ClienteHomeScreenState();
}

class _ClienteHomeScreenState extends State<ClienteHomeScreen> {
  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;

  List<Map<String, dynamic>> _recentTrips = [];
  bool _loadingTrips = true;

  @override
  void initState() {
    super.initState();
    _fetchRecent();
  }

  Future<void> _fetchRecent() async {
    try {
      final res = await ApiClient.instance.getTripHistory(limit: 5);
      if (mounted) setState(() { _recentTrips = res; _loadingTrips = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingTrips = false);
    }
  }

  int _bottomIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeCard(),
                    const SizedBox(height: 20),
                    _buildRecentTrips(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  void _onNavTap(int i) {
    if (i == 0) { setState(() => _bottomIndex = 0); return; }
    if (i == 1) { Navigator.push(context, MaterialPageRoute(builder: (_) => const PerfilScreen())); return; }
    if (i == 2) { Navigator.push(context, MaterialPageRoute(builder: (_) => const RastreoScreen())); return; }
    if (i == 3) { _snack('Próximamente'); return; }
    if (i == 4) { Navigator.push(context, MaterialPageRoute(builder: (_) => const MisEnviosScreen())); return; }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -2))]),
      child: BottomNavigationBar(
        currentIndex: _bottomIndex,
        onTap: _onNavTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: _white,
        selectedItemColor: _primaryDark,
        unselectedItemColor: _textGrey,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Perfil'),
          BottomNavigationBarItem(icon: Icon(Icons.track_changes_outlined), activeIcon: Icon(Icons.track_changes), label: 'Rastrear'),
          BottomNavigationBarItem(icon: Icon(Icons.payments_outlined), activeIcon: Icon(Icons.payments), label: 'Pagos'),
          BottomNavigationBarItem(icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history), label: 'Historial'),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: _white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Builder(builder: (ctx) {
            return IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.black87),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            );
          }),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: _primaryDark, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.person_outline, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ApiClient.instance.nombreCompleto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
              const Text('Cliente', style: TextStyle(fontSize: 10, color: Colors.black45)),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.black54),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A3C6E), Color(0xFF1565C0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.local_shipping, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 12),
          const Text('Pedir viaje', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${ApiClient.instance.nombre ?? ''}, solicita tu transporte', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          SizedBox(
            width: 180, height: 46,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NuevoEnvioScreen())),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Solicitar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, foregroundColor: const Color(0xFF1A3C6E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTrips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Historial de viajes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MisEnviosScreen())),
            child: Text('Ver todos', style: TextStyle(fontSize: 12, color: _primaryDark, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 10),
        if (_loadingTrips)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else if (_recentTrips.isEmpty)
          Container(
            width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(14)),
            child: const Text('No hay viajes aún', style: TextStyle(color: Colors.black45), textAlign: TextAlign.center),
          )
        else
          ...List.generate(_recentTrips.length, (i) => _buildTripTile(_recentTrips[i])),
      ],
    );
  }

  Widget _buildTripTile(Map<String, dynamic> t) {
    final origen = t['origen'] as Map<String, dynamic>?;
    final destino = t['destino'] as Map<String, dynamic>?;
    final estado = t['estado'] as String? ?? '';
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MisEnviosScreen())),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _estadoBg(estado), borderRadius: BorderRadius.circular(10)),
            child: Icon(_estadoIcon(estado), color: _estadoColor(estado), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(origen?['direccion'] as String? ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(destino?['direccion'] as String? ?? '', style: const TextStyle(fontSize: 11, color: _textGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Text('\$${_num(t['precioFinal'] ?? t['precioEstimado'])}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Color _estadoColor(String e) {
    switch (e) {
      case 'buscando_conductor': return const Color(0xFFFF9800);
      case 'aceptado': return const Color(0xFF1E88E5);
      case 'en_curso': return const Color(0xFF1565C0);
      case 'completado': return const Color(0xFF4CAF50);
      case 'finalizado': return const Color(0xFF2E7D32);
      case 'cancelado': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color _estadoBg(String e) {
    return _estadoColor(e).withOpacity(0.12);
  }

  String _num(dynamic v) {
    if (v == null) return '0';
    if (v is num) return v.toStringAsFixed(0);
    final parsed = double.tryParse(v.toString());
    return parsed != null ? parsed.toStringAsFixed(0) : '0';
  }

  IconData _estadoIcon(String e) {
    switch (e) {
      case 'buscando_conductor': return Icons.radar;
      case 'aceptado': return Icons.check_circle_outline;
      case 'en_curso': return Icons.local_shipping;
      case 'completado': return Icons.done_all;
      case 'finalizado': return Icons.star;
      case 'cancelado': return Icons.cancel;
      default: return Icons.circle;
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              color: _primaryDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, color: _white, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(ApiClient.instance.nombreCompleto, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(ApiClient.instance.email ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            _buildDrawerItem(Icons.add_circle_outline, 'Nuevo envío', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NuevoEnvioScreen()))),
            _buildDrawerItem(Icons.route_outlined, 'Mis envíos', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MisEnviosScreen()))),
            _buildDrawerItem(Icons.track_changes_outlined, 'Rastrear', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RastreoScreen()))),
            _buildDrawerItem(Icons.chat_bubble_outline, 'Chat', null),
            _buildDrawerItem(Icons.notifications_outlined, 'Notificaciones', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
            _buildDrawerItem(Icons.poll_outlined, 'Encuestas', null),
            _buildDrawerItem(Icons.person_outline, 'Perfil', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PerfilScreen()))),
            _buildDrawerItem(Icons.history_outlined, 'Historial', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MisEnviosScreen()))),
            const Spacer(),
            const Divider(),
            _buildDrawerItem(Icons.logout, 'Cerrar sesión', _logout, isDestructive: true),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String label, VoidCallback? onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : _textGrey),
      title: Text(label, style: TextStyle(color: isDestructive ? Colors.red : _textDark)),
      onTap: () {
        Navigator.pop(context);
        if (onTap != null) onTap();
      },
    );
  }

  Future<void> _logout() async {
    await ApiClient.instance.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
  }
}

