import 'package:flutter/material.dart';
import 'dart:io';
import 'package:lestate_tsd_new/View/Login.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isDebug = false;
  assert(isDebug = true);
  if (isDebug) {
    HttpOverrides.global = MyHttpOverrides();
  }

  // Проверьте наличие необходимых разрешений
  await _checkPermissions();

  runApp(MyApp());
}

// Проверка и запрос разрешений
Future<void> _checkPermissions() async {
  if (await Permission.storage.request().isGranted) {
    // Разрешение на доступ к хранилищу предоставлено
  } else {
    // Разрешение не предоставлено, вы можете запросить его снова
    await Permission.storage.request();
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    checkForUpdate(); // Проверка обновления при запуске приложения
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primaryColor: Colors.blueGrey,
      ),
      home: const Login(),
    );
  }

  // Проверка наличия обновлений
  Future<void> checkForUpdate() async {
    const String currentVersion = '1.0.0'; // Текущая версия приложения
    const String versionUrl = 'http://1c.sportpoint.ru:5055/tsd/version.json'; // URL JSON-файла с версией

    try {
      final response = await http.get(Uri.parse(versionUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String latestVersion = data['latest_version'];
        final String apkUrl = data['apk_url'];

        if (latestVersion != currentVersion) {
          _showUpdateDialog(context, apkUrl);
        } else {
          showNoUpdateDialog(context);
        }
      } else {
        showErrorDialog(context, 'Ошибка проверки обновления. Код: ${response.statusCode}');
      }
    } catch (e) {
      showErrorDialog(context, 'Произошла ошибка при проверке обновления: $e');
    }
  }

  // Показать диалоговое окно для обновления
  void _showUpdateDialog(BuildContext context, String apkUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Доступно обновление'),
          content: const Text('Доступна новая версия приложения. Хотите обновить?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Отмена'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Обновить'),
              onPressed: () {
                Navigator.of(context).pop();
                _downloadAndInstallApk(apkUrl);
              },
            ),
          ],
        );
      },
    );
  }

  // Загрузка и установка APK
  Future<void> _downloadAndInstallApk(String apkUrl) async {
    try {
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/yourapp.apk';

      // Загрузка APK с сервера
      final response = await http.get(Uri.parse(apkUrl));
      if (response.statusCode == 200) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Открытие APK для установки
        final result = await OpenFile.open(filePath);
        print('OpenFile result: ${result.message}');
      } else {
        showErrorDialog(context, 'Ошибка загрузки APK. Код ответа: ${response.statusCode}');
      }
    } catch (e) {
      showErrorDialog(context, 'Произошла ошибка при загрузке APK: $e');
    }
  }
}

// HttpOverrides класс для использования в отладочном режиме
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void showNoUpdateDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Нет доступных обновлений'),
        content: const Text('Вы используете самую актуальную версию приложения.'),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

void showErrorDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Ошибка'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}