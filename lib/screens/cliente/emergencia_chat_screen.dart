import 'package:flutter/material.dart';
import '../../services/socket_service_client.dart';
import '../../services/sos_service.dart';
import 'chat_thread_screen.dart';

class EmergenciaChatScreen extends StatelessWidget {
  final dynamic alertaId;
  const EmergenciaChatScreen({super.key, required this.alertaId});

  @override
  Widget build(BuildContext context) {
    final id = alertaId.toString();
    return ChatThreadScreen(
      titulo: 'Emergencia #$id',
      subtitulo: 'En l\u00ednea con soporte',
      threadId: id,
      idField: 'alertaId',
      fetchMensajes: () => SosService.getChatMessages(alertaId),
      enviarMensaje: (texto) => SosService.sendChatMessage(alertaId, texto),
      mensajesSocket: SocketServiceClient.instance.onEmergencyMessage,
    );
  }
}