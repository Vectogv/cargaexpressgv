import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ui_compartida.dart' show ColoresApp, DialogoApp;

class PasoTutorial {
  final IconData icono;
  final String titulo;
  final String texto;
  const PasoTutorial(this.icono, this.titulo, this.texto);
}

const claveTutorialCliente = 'tutorial_cliente_visto';
const claveTutorialConductor = 'tutorial_conductor_visto';

const pasosTutorialCliente = [
  PasoTutorial(Icons.add_location_alt_outlined, 'Publica tu envío', 'Indica origen, destino y el precio que quieres pagar.'),
  PasoTutorial(Icons.local_offer_outlined, 'Recibe ofertas', 'Los conductores cercanos ofertan. Revisa y acepta la que prefieras.'),
  PasoTutorial(Icons.my_location, 'Sigue tu viaje en vivo', 'Mira en el mapa dónde va tu conductor hasta la entrega.'),
  PasoTutorial(Icons.pin_outlined, 'Confirma con el PIN', 'Al recibir la carga, dale tu PIN de entrega al conductor y confirma.'),
];

const pasosTutorialConductor = [
  PasoTutorial(Icons.power_settings_new, 'Conéctate', 'Activa el interruptor del inicio para recibir solicitudes.'),
  PasoTutorial(Icons.local_offer_outlined, 'Oferta en solicitudes cercanas', 'Elige un envío cerca de ti y propón tu oferta.'),
  PasoTutorial(Icons.inventory_2_outlined, 'Ve al origen y recoge', 'Cuando el cliente te acepte, ve al punto de recogida y recoge la carga.'),
  PasoTutorial(Icons.pin_outlined, 'Entrega con el PIN', 'Pide el PIN al cliente para finalizar. La comisión de la plataforma es del 10 %.'),
];

/// Muestra el tutorial una sola vez (marca [clave] en SharedPreferences).
Future<void> mostrarTutorialSiToca(BuildContext context, String clave, List<PasoTutorial> pasos) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(clave) == true) return;
    if (!context.mounted) return;
    await prefs.setBool(clave, true);
    if (!context.mounted) return;
    await showDialog<void>(context: context, barrierDismissible: false, builder: (_) => _Tutorial(pasos));
  } catch (_) {
    // Sin preferencias disponibles: no se muestra y no se bloquea el inicio.
  }
}

class _Tutorial extends StatefulWidget {
  final List<PasoTutorial> pasos;
  const _Tutorial(this.pasos);

  @override
  State<_Tutorial> createState() => _TutorialState();
}

class _TutorialState extends State<_Tutorial> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.pasos[_i];
    final ultimo = _i == widget.pasos.length - 1;
    return DialogoApp(
      icono: p.icono,
      titulo: p.titulo,
      cuerpo: p.texto,
      contenido: Text('${_i + 1} de ${widget.pasos.length}',
          textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: ColoresApp.gris)),
      textoPrincipal: ultimo ? 'Entendido' : 'Siguiente',
      onPrincipal: () => ultimo ? Navigator.pop(context) : setState(() => _i++),
      textoSecundario: ultimo ? null : 'Saltar',
      onSecundario: ultimo ? null : () => Navigator.pop(context),
    );
  }
}
