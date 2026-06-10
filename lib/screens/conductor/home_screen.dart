import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../user/auth_screen.dart';
import 'trip_in_progress_screen.dart';
import 'offers_screen.dart';
import 'earnings_screen.dart';
import 'trip_chat_screen.dart';
import 'notifications_screen.dart';
import 'surveys_screen.dart';
import 'profile_screen.dart';
import 'documents_screen.dart';
import 'forum_screen.dart';
import 'sos_alert_screen.dart';
import 'conductor_trip_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _bottomIndex = 0;
  List<Map<String, dynamic>> _nearbyTrips = [];
  bool _loadingTrips = true;

  @override
  void initState() {
    super.initState();
    _fetchNearbyTrips();
  }

  Future<void> _fetchNearbyTrips() async {
    try {
      final trips = await ApiClient.instance.getNearbyTrips(6.2476, -75.5658, radio: 50);
      if (mounted) setState(() { _nearbyTrips = trips; _loadingTrips = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingTrips = false);
    }
  }

  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _primaryBlue = Color(0xFF1565C0);
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;

  final List<_DrawerItem> _drawerItems = [
    _DrawerItem('Viajes', Icons.local_shipping_outlined, 1),
    _DrawerItem('Mis ofertas', Icons.local_offer_outlined, 2),
    _DrawerItem('Notificaciones', Icons.notifications_none, 6, badge: '3'),
    _DrawerItem('Chat', Icons.chat_bubble_outline, 5),
    _DrawerItem('Perfil', Icons.person_outline, 9),
    _DrawerItem('Documentos', Icons.description_outlined, 10),
    _DrawerItem('Ajustes', Icons.settings_outlined, 11),
  ];

  final List<_BottomItem> _bottomItems = [
    _BottomItem('Inicio', Icons.home_rounded, 0),
    _BottomItem('Foro', Icons.forum_outlined, 7),
    _BottomItem('Encuestas', Icons.poll_outlined, 8),
    _BottomItem('Ganancias', Icons.monetization_on_outlined, 4),
    _BottomItem('SOS', Icons.sos, -2),
  ];

  void _navigate(int index) {
    final routes = <int, Widget>{
      1: const TripInProgressScreen(),
      2: const OffersScreen(),
      3: const TripInProgressScreen(),
      4: const EarningsScreen(),
      5: const TripChatScreen(),
      6: const NotificationsScreen(),
      7: const ForumScreen(),
      8: const SurveysScreen(),
      9: const ProfileScreen(),
      10: const DocumentsScreen(),
    };
    final route = routes[index];
    if (route != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => route));
    }
  }

  void _openSos() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SOSAlertScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _bgLight,
      drawer: _buildDrawer(),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: IndexedStack(
              index: _bottomIndex,
              children: [
                _buildHomeContent(),
                const ForumScreen(),
                const SurveysScreen(),
                const EarningsScreen(),
                const SOSAlertScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Future<void> _logout() async {
    await ApiClient.instance.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A3C6E), Color(0xFF1565C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: _white.withOpacity(0.2),
                  backgroundImage: const NetworkImage(
                    'https://randomuser.me/api/portraits/men/32.jpg',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ApiClient.instance.nombreCompleto,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _accentGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'En línea',
                          style:
                              TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ..._drawerItems.map((item) => _buildDrawerItem(item)),
                const Divider(),
                _buildDrawerItem(
                  _DrawerItem('Cerrar sesión', Icons.logout, -1,
                      isDestructive: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(_DrawerItem item) {
    return ListTile(
      leading: Icon(item.icon,
          color: item.isDestructive ? Colors.red : _textGrey),
      title: Text(
        item.label,
        style: TextStyle(
          color: item.isDestructive ? Colors.red : _textDark,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: item.badge != null
          ? Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                item.badge!,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            )
          : null,
      onTap: () {
        Navigator.pop(context);
        if (item.index == -1) {
          _logout();
        } else {
          _navigate(item.index);
        }
      },
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _bottomIndex,
        onTap: (i) {
          if (_bottomItems[i].index == -2) {
            _openSos();
          } else {
            setState(() => _bottomIndex = i);
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: _white,
        selectedItemColor: _primaryBlue,
        unselectedItemColor: _textGrey,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 0,
        items: _bottomItems.map((item) {
          if (item.index == -2) {
            return BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.sos, color: Colors.red.shade700, size: 22),
              ),
              label: 'SOS',
            );
          }
          return BottomNavigationBarItem(
            icon: Icon(item.icon),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _white,
      padding: const EdgeInsets.only(top: 44, left: 8, right: 12, bottom: 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.menu_rounded, color: _textDark, size: 24),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _primaryDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_shipping, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Buenos días, ${ApiClient.instance.nombre}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.verified, color: _accentGreen, size: 11),
                    const SizedBox(width: 3),
                    Text(
                      'Conductor verificado',
                      style: TextStyle(
                        fontSize: 10,
                        color: _accentGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications_outlined,
                    color: _textDark, size: 24),
                onPressed: () => _navigate(6),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsRow(),
          const SizedBox(height: 20),
          _buildAvailableTrips(),
          const SizedBox(height: 20),
          _buildMoreTripsCard(),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            Icons.monetization_on_outlined,
            '\$12,400',
            'Ganancias del mes',
            const Color(0xFFE8F5E9),
            const Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            Icons.route_outlined,
            '8',
            'Viajes completados',
            const Color(0xFFE3F2FD),
            const Color(0xFF1565C0),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            Icons.star_rounded,
            '4.8',
            'Calificación',
            const Color(0xFFFFF8E1),
            const Color(0xFFFF8F00),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      IconData icon, String value, String label, Color bg, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 8.5, color: _textGrey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableTrips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Viajes disponibles',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            if (_nearbyTrips.length > 3)
              GestureDetector(
                onTap: () => _showAllTrips(),
                child: Text(
                  'Ver todos',
                  style: TextStyle(
                    fontSize: 12,
                    color: _primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingTrips)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else if (_nearbyTrips.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(14)),
            child: const Center(child: Text('No hay viajes disponibles cerca', style: TextStyle(color: Colors.black45))),
          )
        else
          ..._nearbyTrips.take(3).map((t) => _buildTripCard(t)),
      ],
    );
  }

  void _showAllTrips() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _AllTripsScreen(trips: _nearbyTrips)));
  }

  Widget _buildMoreTripsCard() {
    if (_nearbyTrips.length <= 3) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        title: const Text('Ver todos los viajes disponibles', style: TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: _showAllTrips,
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> t) {
    final origen = t['origen'] as Map<String, dynamic>?;
    final destino = t['destino'] as Map<String, dynamic>?;
    final precio = t['precioEstimado'] as num?;
    final distancia = t['distancia'] as num?;
    final carga = t['carga'] as String? ?? 'No especificada';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(16), boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
      ]),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('#${t['id']}', style: TextStyle(fontSize: 11, color: _primaryBlue, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _accentGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: Text('${distancia?.toStringAsFixed(1) ?? '?'} km', style: TextStyle(color: _accentGreen, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: _accentGreen, shape: BoxShape.circle, border: Border.all(color: _white, width: 2), boxShadow: [BoxShadow(color: _accentGreen.withOpacity(0.4), blurRadius: 4)])),
                Container(width: 2, height: 30, color: _textGrey.withOpacity(0.3), margin: const EdgeInsets.symmetric(vertical: 3)),
                Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: _white, width: 2), boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 4)])),
              ]),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(origen?['direccion'] as String? ?? 'Origen', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark)),
                const SizedBox(height: 14),
                Text(destino?['direccion'] as String? ?? 'Destino', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark)),
              ])),
            ]),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(carga, style: const TextStyle(fontSize: 12, color: _textGrey), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('\$${precio?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textDark)),
                const Text('Presupuesto', style: TextStyle(fontSize: 10, color: _textGrey)),
              ]),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ConductorTripDetailScreen(trip: t))),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryDark, foregroundColor: _white, padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0,
                ),
                child: const Text('Ver detalles', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllTripsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> trips;
  const _AllTripsScreen({required this.trips});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white, foregroundColor: const Color(0xFF1A1A2E), elevation: 0,
        title: const Text('Viajes disponibles', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: trips.length,
        itemBuilder: (_, i) => _buildTripCard(context, trips[i]),
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, Map<String, dynamic> t) {
    final origen = t['origen'] as Map<String, dynamic>?;
    final destino = t['destino'] as Map<String, dynamic>?;
    final precio = t['precioEstimado'] as num?;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(origen?['direccion'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(destino?['direccion'] as String? ?? '', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t['carga'] as String? ?? '', style: const TextStyle(fontSize: 12, color: Colors.black45)),
            Text('\$${precio?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ConductorTripDetailScreen(trip: t))),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3C6E), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0,
              ),
              child: const Text('Ver detalles'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DrawerItem {
  final String label;
  final IconData icon;
  final int index;
  final String? badge;
  final bool isDestructive;

  const _DrawerItem(this.label, this.icon, this.index,
      {this.badge, this.isDestructive = false});
}

class _BottomItem {
  final String label;
  final IconData icon;
  final int index;

  const _BottomItem(this.label, this.icon, this.index);
}
