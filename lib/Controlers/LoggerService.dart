import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LoggerService {
  late File logFile;

  Future<void> initializeLogFile() async {
    final directory = await getApplicationDocumentsDirectory();
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
}