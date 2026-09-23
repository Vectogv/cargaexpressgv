import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/media.dart';
import '../../services/api/http_client.dart';
import '../../services/notification_service.dart';

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

/// Hoja inferior con las notificaciones que cuenta el badge de la campana
/// (NotificationService). Compartida por DashboardScreen y AdminLiveScreen
/// para que la campana nunca sea un botón muerto. [onMarkedAllRead] se llama
/// tras "Marcar todas leídas" para que la pantalla actualice su badge.
void showAdminNotificationsSheet(BuildContext context, {VoidCallback? onMarkedAllRead}) {
  final notifs = NotificationService.instance.notifications;
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Notificaciones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (notifs.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        NotificationService.instance.markAllRead();
                        onMarkedAllRead?.call();
                        Navigator.pop(sheetCtx);
                      },
                      child: const Text('Marcar todas leídas'),
                    ),
                ],
              ),
              const Divider(),
              if (notifs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('Sin notificaciones', style: TextStyle(color: Colors.black45))),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: notifs.take(20).map((n) => ListTile(
                      dense: true,
                      leading: Icon(Icons.circle, size: 8, color: n['leido'] == true ? Colors.grey : const Color(0xFF1565C0)),
                      title: Text('${n['titulo'] ?? 'Notificación'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      subtitle: Text('${n['mensaje'] ?? 'Sin detalle'}', style: const TextStyle(fontSize: 11)),
                    )).toList(),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

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
