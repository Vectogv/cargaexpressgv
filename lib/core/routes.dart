import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../screens/user/auth_screen.dart';
import '../screens/user/login_screen.dart';
import '../screens/user/register_screen.dart';
import '../screens/cliente/home_screen.dart' as cliente;
import '../screens/cliente/rastreo_screen.dart';
import '../screens/cliente/nuevo_envio_screen.dart';
import '../screens/cliente/mis_envios_screen.dart';
import '../screens/cliente/viaje_detalle_screen.dart';
import '../screens/cliente/chat_screen.dart';
import '../screens/cliente/perfil_screen.dart';
import '../screens/cliente/pagos_screen.dart';
import '../screens/cliente/ajustes_screen.dart';
import '../screens/conductor/home_screen.dart' as conductor;
import '../screens/conductor/conductor_trip_detail_screen.dart';
import '../screens/conductor/trip_in_progress_screen.dart';
import '../screens/conductor/trip_chat_screen.dart';
import '../services/api_client.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final loggedIn = ApiClient.instance.token != null;
    final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';
    if (!loggedIn && !isAuthRoute) return '/login';
    if (loggedIn && isAuthRoute) return '/';
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) {
        final rol = ApiClient.instance.rol;
        if (rol == 'cliente') return const cliente.ClienteHomeScreen();
        if (rol == 'conductor') return const conductor.HomeScreen();
        return const AuthScreen();
      },
    ),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/cliente/nuevo-envio', builder: (_, __) => const NuevoEnvioScreen()),
    GoRoute(path: '/cliente/rastreo', builder: (_, __) => const RastreoScreen()),
    GoRoute(path: '/cliente/mis-envios', builder: (_, __) => const MisEnviosScreen()),
    GoRoute(path: '/cliente/perfil', builder: (_, __) => const PerfilScreen()),
    GoRoute(path: '/cliente/pagos', builder: (_, __) => const PagosScreen()),
    GoRoute(path: '/cliente/ajustes', builder: (_, __) => const AjustesScreen()),
    GoRoute(
      path: '/cliente/chat/:tripId',
      builder: (_, state) => ChatScreen(trip: {'id': state.pathParameters['tripId']}),
    ),
    GoRoute(
      path: '/conductor/trip/:tripId',
      builder: (_, state) => ConductorTripDetailScreen(trip: {'id': state.pathParameters['tripId']}),
    ),
    GoRoute(
      path: '/conductor/trip-progress/:tripId',
      builder: (_, state) => TripInProgressScreen(trip: {'id': state.pathParameters['tripId']}),
    ),
    GoRoute(
      path: '/conductor/chat/:tripId',
      builder: (_, state) => TripChatScreen(trip: {'id': state.pathParameters['tripId']}),
    ),
  ],
);
