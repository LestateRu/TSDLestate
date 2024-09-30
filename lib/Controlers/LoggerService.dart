import 'dart:io';

class LoggerService {
  late File logFile;

  Future<void> initializeLogFile() async {
    const directoryPath = '/storage/emulated/0/LogLestate/';
    final directory = Directory(directoryPath);

    // Проверяем, существует ли директория, и создаем ее при необходимости
    if (!(await directory.exists())) {
      await directory.create(recursive: true);
    }

    logFile = File('${directory.path}/app_logs.txt');
    if (!(await logFile.exists())) {
      await logFile.create();
    }
  }

  Future<void> log(String message) async {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] - LOG - $message\n';
    await logFile.writeAsString(logMessage, mode: FileMode.append);
  }

  Future<void> error(String message) async {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] - ERROR - $message\n';
    await logFile.writeAsString(logMessage, mode: FileMode.append);
  }

  // Функция для удаления записей старше 30 дней
  Future<void> deleteOldLogs() async {
    final now = DateTime.now();
    final lines = await logFile.readAsLines(); // Читаем все строки файла
    final newLines = <String>[];

    for (var line in lines) {
      // Предполагается, что каждая строка начинается с даты в формате ISO 8601
      final dateMatch = RegExp(r'\[(.*?)\]').firstMatch(line);
      if (dateMatch != null) {
        final timestamp = dateMatch.group(1);
        if (timestamp != null) {
          final logDate = DateTime.tryParse(timestamp);
          if (logDate != null) {
            final difference = now.difference(logDate).inDays;
            if (difference <= 30) {
              newLines.add(line); // Оставляем только записи моложе 30 дней
            }
          }
        }
      }
    }

    // Перезаписываем файл только с новыми строками
    await logFile.writeAsString(newLines.join('\n'));
  }
}