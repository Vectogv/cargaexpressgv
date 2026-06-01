import 'api_client.dart';

class AdminDashboard {
  final int totalUsers;
  final int totalDrivers;
  final int activeVehicles;
  final int todayShipments;
  final double totalEarnings;
  final double todayEarnings;
  final double monthEarnings;

  AdminDashboard({
    required this.totalUsers,
    required this.totalDrivers,
    required this.activeVehicles,
    required this.todayShipments,
    required this.totalEarnings,
    required this.todayEarnings,
    required this.monthEarnings,
  });

  factory AdminDashboard.fromJson(Map<String, dynamic> json) => AdminDashboard(
    totalUsers: json['totalUsers'] ?? 0,
    totalDrivers: json['totalDrivers'] ?? 0,
    activeVehicles: json['activeVehicles'] ?? 0,
    todayShipments: json['todayShipments'] ?? 0,
    totalEarnings: (json['totalEarnings'] ?? 0).toDouble(),
    todayEarnings: (json['todayEarnings'] ?? 0).toDouble(),
    monthEarnings: (json['monthEarnings'] ?? 0).toDouble(),
  );
}

class AdminUser {
  final int id;
  final String? nombre;
  final String? apellido;
  final String email;
  final String? rol;
  final String? telefono;
  final int? edad;
  final String? avatar;
  final bool suspendido;
  final String? createdAt;

  AdminUser({
    required this.id,
    this.nombre,
    this.apellido,
    required this.email,
    this.rol,
    this.telefono,
    this.edad,
    this.avatar,
    required this.suspendido,
    this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    id: json['id'],
    nombre: json['nombre'],
    apellido: json['apellido'],
    email: json['email'],
    rol: json['rol'],
    telefono: json['telefono'],
    edad: json['edad'],
    avatar: json['avatar'],
    suspendido: json['suspendido'] ?? false,
    createdAt: json['createdAt'],
  );

  String get displayName => '${nombre ?? ''} ${apellido ?? ''}'.trim();
}

class AdminDriver {
  final int id;
  final int usuarioId;
  final String cedula;
  final String placa;
  final String? tipoVehiculo;
  final String? capacidad;
  final bool online;
  final int? calificacion;
  final int? totalViajes;
  final int? horasActivo;
  final String? fotoConductor;
  final String? fotoVehiculo;
  final Map<String, dynamic>? usuario;
  final String? createdAt;

  AdminDriver({
    required this.id,
    required this.usuarioId,
    required this.cedula,
    required this.placa,
    this.tipoVehiculo,
    this.capacidad,
    required this.online,
    this.calificacion,
    this.totalViajes,
    this.horasActivo,
    this.fotoConductor,
    this.fotoVehiculo,
    this.usuario,
    this.createdAt,
  });

  factory AdminDriver.fromJson(Map<String, dynamic> json) => AdminDriver(
    id: json['id'],
    usuarioId: json['usuarioId'],
    cedula: json['cedula'],
    placa: json['placa'],
    tipoVehiculo: json['tipoVehiculo'],
    capacidad: json['capacidad'],
    online: json['online'] ?? false,
    calificacion: json['calificacion'],
    totalViajes: json['totalViajes'],
    horasActivo: json['horasActivo'],
    fotoConductor: json['fotoConductor'],
    fotoVehiculo: json['fotoVehiculo'],
    usuario: json['usuario'],
    createdAt: json['createdAt'],
  );

  String get displayName {
    final u = usuario;
    if (u != null) {
      final n = '${u['nombre'] ?? ''} ${u['apellido'] ?? ''}'.trim();
      if (n.isNotEmpty) return n;
      return u['email'] ?? '';
    }
    return '';
  }

  bool get suspendido => (usuario?['suspendido'] as bool?) ?? false;
}

class AdminTrip {
  final int id;
  final String estado;
  final String origenDireccion;
  final String destinoDireccion;
  final String? carga;
  final double? precioEstimado;
  final double? precioFinal;
  final String? motivoCancelacion;
  final int? calificacionCliente;
  final Map<String, dynamic>? cliente;
  final Map<String, dynamic>? conductor;
  final String? createdAt;

  AdminTrip({
    required this.id,
    required this.estado,
    required this.origenDireccion,
    required this.destinoDireccion,
    this.carga,
    this.precioEstimado,
    this.precioFinal,
    this.motivoCancelacion,
    this.calificacionCliente,
    this.cliente,
    this.conductor,
    this.createdAt,
  });

  factory AdminTrip.fromJson(Map<String, dynamic> json) => AdminTrip(
    id: json['id'],
    estado: json['estado'],
    origenDireccion: json['origenDireccion'],
    destinoDireccion: json['destinoDireccion'],
    carga: json['carga'],
    precioEstimado: (json['precioEstimado'] ?? 0).toDouble(),
    precioFinal: (json['precioFinal'] ?? 0).toDouble(),
    motivoCancelacion: json['motivoCancelacion'],
    calificacionCliente: json['calificacionCliente'],
    cliente: json['cliente'],
    conductor: json['conductor'],
    createdAt: json['createdAt'],
  );

  String get clienteNombre {
    final c = cliente;
    if (c == null) return '';
    final n = '${c['nombre'] ?? ''} ${c['apellido'] ?? ''}'.trim();
    if (n.isNotEmpty) return n;
    return (c['email'] as String?) ?? '';
  }

  String get conductorNombre {
    final c = conductor;
    if (c == null) return '';
    final n = '${c['nombre'] ?? ''} ${c['apellido'] ?? ''}'.trim();
    if (n.isNotEmpty) return n;
    return (c['placa'] as String?) ?? '';
  }
}

class AdminEarning {
  final int id;
  final double monto;
  final int conductorId;
  final int? viajeId;
  final Map<String, dynamic>? conductor;
  final Map<String, dynamic>? viaje;
  final String? createdAt;

  AdminEarning({
    required this.id,
    required this.monto,
    required this.conductorId,
    this.viajeId,
    this.conductor,
    this.viaje,
    this.createdAt,
  });

  factory AdminEarning.fromJson(Map<String, dynamic> json) => AdminEarning(
    id: json['id'],
    monto: (json['monto'] ?? 0).toDouble(),
    conductorId: json['conductorId'],
    viajeId: json['viajeId'],
    conductor: json['conductor'],
    viaje: json['viaje'],
    createdAt: json['createdAt'],
  );
}

class AdminService {
  final ApiClient _api = ApiClient();

  Future<AdminDashboard> getDashboard() async {
    final res = await _api.get('/admin/dashboard');
    return AdminDashboard.fromJson(res);
  }

  Future<List<AdminUser>> getUsers() async {
    final res = await _api.getList('/admin/users');
    return res.map((e) => AdminUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<AdminDriver>> getDrivers() async {
    final res = await _api.getList('/admin/drivers');
    return res.map((e) => AdminDriver.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<AdminTrip>> getTrips() async {
    final res = await _api.getList('/admin/trips');
    return res.map((e) => AdminTrip.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<AdminEarning>> getEarnings() async {
    final res = await _api.getList('/admin/earnings');
    return res.map((e) => AdminEarning.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> deleteUser(int id) async {
    await _api.delete('/admin/users/$id');
  }

  Future<Map<String, dynamic>> updateUser(int id, Map<String, dynamic> data) async {
    return await _api.put('/admin/users/$id', body: data);
  }

  Future<Map<String, dynamic>> toggleSuspendUser(int id) async {
    return await _api.put('/admin/users/$id/suspend');
  }

  Future<Map<String, dynamic>> uploadUserAvatar(int id, List<int> bytes, String filename) async {
    return await _api.uploadBytes('/admin/users/$id/avatar', bytes, filename, 'file');
  }

  Future<Map<String, dynamic>> getProfile() async {
    return await _api.get('/admin/profile');
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    return await _api.put('/admin/profile', body: data);
  }

  Future<Map<String, dynamic>> uploadProfileAvatar(List<int> bytes, String filename) async {
    return await _api.uploadBytes('/admin/profile/avatar', bytes, filename, 'file');
  }

  Future<Map<String, dynamic>> get(String path) async {
    return await _api.get(path);
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) async {
    return await _api.post(path, body: body);
  }

  Future<Map<String, dynamic>> getPendingPayments() async {
    return await _api.get('/admin/payments/pending');
  }

  Future<void> confirmPayment(String paymentId) async {
    await _api.post('/admin/payments/$paymentId/confirm');
  }

  Future<void> rejectPayment(String paymentId) async {
    await _api.post('/admin/payments/$paymentId/reject');
  }

  Future<void> saveNequiConfig(String numero, String titular) async {
    await _api.put('/admin/payments/nequi-config', body: {
      'numero': numero,
      'titular': titular,
    });
  }
}
