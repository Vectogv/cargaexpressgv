import 'dart:io';

/// Exporta los logs a un archivo temporal (solo plataformas con dart:io).
Future<void> exportLogsToFile(List<Map<String, dynamic>> buffer) async {
  try {
    final file = File(
      '${Directory.systemTemp.path}/cargaexpress_logs_${DateTime.now().millisecondsSinceEpoch}.txt',
    );
    final content = buffer
        .map((e) =>
            '[${e['timestamp']}] [${e['level']}] ${e['message']}${e['error'] != null ? ' | ${e['error']}' : ''}')
        .join('\n');
    await file.writeAsString(content);
  } catch (_) {}
}