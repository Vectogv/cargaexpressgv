import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/media.dart';
import '../../services/api/http_client.dart';

/// Mensaje legible de un error de API (usa el mensaje del backend).
String adminErrorText(Object e) =>
    e is ApiException ? e.message : e.toString().replaceFirst('Exception: ', '');

/// Muestra un SnackBar si el State sigue montado.
void adminSnack(State state, String msg, {bool error = false, Color? color}) {
  if (!state.mounted) return;
  ScaffoldMessenger.of(state.context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: color ?? (error ? Colors.red : null)),
  );
}

/// Lista de mapas tolerante a `[...]` o `{data:[...]}`.
List<Map<String, dynamic>> adminMapList(dynamic data) =>
    HttpClient.parseListLenient(data).whereType<Map<String, dynamic>>().toList();

/// Sondeo periódico que solo se ejecuta cuando la pantalla es visible: la app
/// está en primer plano y la ruta es la actual (no hay otra pantalla encima).
/// Al volver a ser visible se refresca de inmediato.
mixin VisiblePolling<T extends StatefulWidget> on State<T> {
  Timer? _pollTimer;
  AppLifecycleListener? _lifecycle;
  bool _appActive = true;
  bool _missedTick = false;
  Future<void> Function()? _onPoll;

  void startPolling(Duration interval, Future<void> Function() onPoll) {
    _onPoll = onPoll;
    _lifecycle ??= AppLifecycleListener(
      onStateChange: (state) {
        _appActive = state == AppLifecycleState.resumed;
        if (_appActive && _missedTick) _tick();
      },
    );
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) => _tick());
  }

  bool get _visible => mounted && _appActive && (ModalRoute.of(context)?.isCurrent ?? true);

  void _tick() {
    if (_visible) {
      _missedTick = false;
      _onPoll?.call();
    } else {
      _missedTick = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Depender de ModalRoute hace que se notifique al volver a esta ruta:
    // refrescar de inmediato si se saltó un ciclo mientras estaba oculta.
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    if (current && _missedTick) _tick();
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _lifecycle?.dispose();
    _lifecycle = null;
    _onPoll = null;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

/// Imagen de un documento (posiblemente privado y firmado) con placeholder
/// de error. Siempre resuelve la URL con [resolveMediaUrl].
class AdminDocImage extends StatelessWidget {
  final String? path;
  final double? height;
  final double? width;
  final BoxFit fit;
  const AdminDocImage(this.path, {super.key, this.height, this.width, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final url = resolveMediaUrl(path);
    final placeholder = Container(
      height: height,
      width: width,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
    );
    if (url == null) return placeholder;
    return Image.network(
      url,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (_, _, _) => placeholder,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : SizedBox(
              height: height,
              width: width,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
    );
  }
}
