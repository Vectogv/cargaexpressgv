import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'driver_home_screen.dart';
import 'client_home_screen.dart';
import 'admin_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  String _storedEmail = '';
  String _storedName = '';
  String _storedToken = '';

  @override
  void initState() {
    super.initState();
    _loadStoredInfo();
  }

  Future<void> _loadStoredInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _storedToken = prefs.getString('token') ?? '';
      _storedEmail = prefs.getString('userEmail') ?? '';
      _storedName = prefs.getString('userName') ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: Text(
                'CargaExpress',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1.5,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 24),
                      Row(
                        children: [
                          _TabButton(
                            label: 'Iniciar Sesión',
                            selected: _isLogin,
                            onTap: () => setState(() => _isLogin = true),
                          ),
                          SizedBox(width: 16),
                          _TabButton(
                            label: 'Registrarse',
                            selected: !_isLogin,
                            onTap: () => setState(() => _isLogin = false),
                          ),
                        ],
                      ),
                      SizedBox(height: 28),
                      _isLogin ? _LoginForm(onLogin: _loadStoredInfo) : _RegisterForm(),
                      if (_storedToken.isNotEmpty) _buildDebugInfo(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugInfo() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 16, bottom: 24),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.bug_report, size: 16, color: Colors.grey[600]),
            SizedBox(width: 6),
            Text('DEBUG — Sesión activa',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: Colors.grey[600])),
          ]),
          SizedBox(height: 8),
          _debugRow('Nombre', _storedName),
          _debugRow('Email', _storedEmail),
          _debugRow('Token', _storedToken.length > 40
              ? '${_storedToken.substring(0, 40)}...' : _storedToken),
        ],
      ),
    );
  }

  Widget _debugRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 11,
              fontWeight: FontWeight.w600, color: Colors.grey[700])),
          Expanded(child: Text(value, style: TextStyle(fontSize: 11,
              color: Colors.grey[600]))),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? Colors.black : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: selected ? FontWeight.bold : FontWeight.w400,
            color: selected ? Colors.black : Colors.grey[500],
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatefulWidget {
  final VoidCallback? onLogin;
  const _LoginForm({this.onLogin});

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadStoredEmail();
  }

  Future<void> _loadStoredEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail');
    if (email != null && email.isNotEmpty) {
      _emailCtrl.text = email;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      final user = await AuthService().login(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userRole', user.rol);
      widget.onLogin?.call();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, _, _) {
            if (user.rol == 'admin') return const AdminScreen();
            if (user.rol == 'conductor') return const DriverHomeScreen();
            return const ClientHomeScreen();
          },
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bienvenido de nuevo',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
        SizedBox(height: 8),
        Text('Ingresa tus datos para continuar',
            style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        SizedBox(height: 24),
        _TextField(controller: _emailCtrl, hint: 'Correo electrónico', keyboardType: TextInputType.emailAddress),
        SizedBox(height: 16),
        _TextField(controller: _passwordCtrl, hint: 'Contraseña', obscureText: true),
        SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            child: Text('¿Olvidaste tu contraseña?',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ),
        SizedBox(height: 8),
        _loading
            ? Center(child: CircularProgressIndicator())
            : _PrimaryButton(label: 'Iniciar Sesión', onPressed: _login),
        SizedBox(height: 24),
        _TermsText(),
        SizedBox(height: 24),
      ],
    );
  }
}

enum _Role { conductor, cliente }

class _RegisterForm extends StatefulWidget {
  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  _Role _role = _Role.conductor;
  bool _loading = false;

  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _edadCtrl = TextEditingController();
  final _cedulaCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  final _tipoVehiculoCtrl = TextEditingController();
  final _capacidadCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _edadCtrl.dispose();
    _cedulaCtrl.dispose();
    _placaCtrl.dispose();
    _tipoVehiculoCtrl.dispose();
    _capacidadCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() => _loading = true);
    try {
      await AuthService().register(
        nombre: _nombreCtrl.text,
        apellido: _apellidoCtrl.text,
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        telefono: _telefonoCtrl.text,
        rol: _role == _Role.conductor ? 'conductor' : 'cliente',
        edad: _role == _Role.conductor ? int.tryParse(_edadCtrl.text) : null,
        cedula: _role == _Role.conductor ? _cedulaCtrl.text : null,
        placa: _role == _Role.conductor ? _placaCtrl.text : null,
        tipoVehiculo: _role == _Role.conductor && _tipoVehiculoCtrl.text.isNotEmpty ? _tipoVehiculoCtrl.text : null,
        capacidad: _role == _Role.conductor && _capacidadCtrl.text.isNotEmpty ? _capacidadCtrl.text : null,
      );
      if (!mounted) return;
      if (_role == _Role.conductor) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, _, _) => const DriverHomeScreen(),
            transitionsBuilder: (_, anim, _, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (_, _, _) => const ClientHomeScreen(),
            transitionsBuilder: (_, anim, _, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
          (_) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Crear cuenta', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
        SizedBox(height: 8),
        Text('Selecciona tu tipo de cuenta', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        SizedBox(height: 20),
        Row(children: [
          Expanded(child: _RoleCard(
            icon: Icons.local_shipping, label: 'Conductor',
            selected: _role == _Role.conductor,
            onTap: () => setState(() => _role = _Role.conductor),
          )),
          SizedBox(width: 12),
          Expanded(child: _RoleCard(
            icon: Icons.person, label: 'Cliente',
            selected: _role == _Role.cliente,
            onTap: () => setState(() => _role = _Role.cliente),
          )),
        ]),
        SizedBox(height: 24),
        Row(children: [
          Expanded(child: _TextField(controller: _nombreCtrl, hint: 'Nombre')),
          SizedBox(width: 12),
          Expanded(child: _TextField(controller: _apellidoCtrl, hint: 'Apellido')),
        ]),
        SizedBox(height: 16),
        if (_role == _Role.conductor) ...[
          Row(children: [
            Expanded(child: _TextField(controller: _edadCtrl, hint: 'Edad', keyboardType: TextInputType.number)),
            SizedBox(width: 12),
            Expanded(child: _TextField(controller: _cedulaCtrl, hint: 'Cédula', keyboardType: TextInputType.number)),
          ]),
          SizedBox(height: 16),
          _TextField(controller: _placaCtrl, hint: 'Placa del vehículo'),
          SizedBox(height: 16),
          _TextField(controller: _tipoVehiculoCtrl, hint: 'Tipo de vehículo (Camioneta, Camión...)'),
          SizedBox(height: 16),
          _TextField(controller: _capacidadCtrl, hint: 'Capacidad (ej: 1.5 ton)'),
          SizedBox(height: 16),
        ] else ...[
          _TextField(controller: _telefonoCtrl, hint: 'Teléfono', keyboardType: TextInputType.phone),
          SizedBox(height: 16),
        ],
        _TextField(controller: _emailCtrl, hint: 'Correo electrónico', keyboardType: TextInputType.emailAddress),
        SizedBox(height: 16),
        _TextField(controller: _passwordCtrl, hint: 'Contraseña', obscureText: true),
        SizedBox(height: 24),
        _loading
            ? Center(child: CircularProgressIndicator())
            : _PrimaryButton(
                label: _role == _Role.conductor ? 'Registrarse como Conductor' : 'Registrarse como Cliente',
                onPressed: _register,
              ),
        SizedBox(height: 24),
        _TermsText(),
        SizedBox(height: 24),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.black : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: selected ? Colors.white : Colors.grey[600],
            ),
            SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;

  const _TextField({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _TermsText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(color: Colors.grey[500], fontSize: 12),
        children: [
          TextSpan(text: 'Al continuar, aceptas nuestros '),
          TextSpan(
            text: 'Términos y Condiciones',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
          TextSpan(text: ' y '),
          TextSpan(
            text: 'Política de Privacidad',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
          TextSpan(text: '.'),
        ],
      ),
    );
  }
}


