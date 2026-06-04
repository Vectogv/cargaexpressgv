import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  String _rol = 'cliente';
  bool _loading = false;
  bool _obscure = true;

  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _edadCtrl = TextEditingController();

  final _cedulaCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  final _capacidadCtrl = TextEditingController();
  String _tipoVehiculo = 'sedan';

  final List<String> _tiposVehiculo = [
    'sedan',
    'camioneta',
    'camion',
    'moto',
    'furgon',
  ];

  Future<void> _register() async {
    if (_nombreCtrl.text.isEmpty ||
        _apellidoCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty ||
        _passCtrl.text.isEmpty ||
        _telefonoCtrl.text.isEmpty ||
        _edadCtrl.text.isEmpty) {
      _showSnack('Completa todos los campos obligatorios');
      return;
    }
    if (_rol == 'conductor' &&
        (_cedulaCtrl.text.isEmpty ||
            _placaCtrl.text.isEmpty ||
            _capacidadCtrl.text.isEmpty)) {
      _showSnack('Completa los datos del conductor');
      return;
    }

    setState(() => _loading = true);

    final Map<String, dynamic> body = {
      'nombre': _nombreCtrl.text.trim(),
      'apellido': _apellidoCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'password': _passCtrl.text,
      'telefono': _telefonoCtrl.text.trim(),
      'rol': _rol,
    };
    if (_edadCtrl.text.trim().isNotEmpty) {
      body['edad'] = int.tryParse(_edadCtrl.text.trim()) ?? 0;
    }

    if (_rol == 'conductor') {
      body['cedula'] = _cedulaCtrl.text.trim();
      body['placa'] = _placaCtrl.text.trim().toUpperCase();
      body['tipoVehiculo'] = _tipoVehiculo;
      body['capacidad'] = _capacidadCtrl.text.trim();
    }

    try {
      await ApiClient.instance.register(body);
      if (mounted) {
        _showSnack('Cuenta creada exitosamente');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (mounted) _showSnack(msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Carga',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87),
              ),
              TextSpan(
                text: 'Express',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87),
              ),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Registrarse',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),

            const Text(
              'Tipo de cuenta',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _rolTab('cliente', 'Cliente'),
                  _rolTab('conductor', 'Conductor'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildField(controller: _nombreCtrl, label: 'Nombre'),
            const SizedBox(height: 12),
            _buildField(controller: _apellidoCtrl, label: 'Apellido'),
            const SizedBox(height: 12),
            _buildField(
              controller: _emailCtrl,
              label: 'Correo electrónico',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _passCtrl,
              label: 'Contraseña',
              obscure: _obscure,
              suffix: IconButton(
                icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    color: Colors.black45,
                    size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _telefonoCtrl,
              label: 'Teléfono',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _edadCtrl,
              label: 'Edad',
              keyboardType: TextInputType.number,
            ),

            if (_rol == 'conductor') ...[
              const SizedBox(height: 20),
              const Text(
                'Datos del vehículo',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54),
              ),
              const SizedBox(height: 8),
              _buildField(
                controller: _cedulaCtrl,
                label: 'Cédula',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: _placaCtrl,
                label: 'Placa',
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _tipoVehiculo,
                    isExpanded: true,
                    hint: const Text('Tipo de vehículo',
                        style:
                            TextStyle(color: Colors.black45, fontSize: 14)),
                    items: _tiposVehiculo
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(
                                  t[0].toUpperCase() + t.substring(1),
                                  style: const TextStyle(fontSize: 14)),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _tipoVehiculo = v ?? 'sedan'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: _capacidadCtrl,
                label: 'Capacidad (ej: 500 kg)',
              ),
            ],

            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Crear cuenta',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _rolTab(String value, String label) {
    final selected = _rol == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _rol = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      textCapitalization: textCapitalization,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black45, fontSize: 14),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
