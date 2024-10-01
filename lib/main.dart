import 'package:flutter/material.dart';
import 'package:lestate_tsd_new/Controlers/LoggerService.dart';
import 'dart:io';
import 'package:lestate_tsd_new/View/Login.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_installer/app_installer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isDebug = true;
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
  final storageStatus = await Permission.storage.request();
  final installStatus = await Permission.manageExternalStorage.request();

  if (storageStatus.isGranted && installStatus.isGranted) {
  } else {
    // Разрешения не предоставлены, запросим их снова
    if (!storageStatus.isGranted) {
      await Permission.storage.request();
    }
    if (!installStatus.isGranted) {
      await Permission.manageExternalStorage.request();
    }
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primaryColor: Colors.blueGrey,
      ),
      home: UpdateChecker(),
    );
  }
}

class UpdateChecker extends StatefulWidget {
  @override
  _UpdateCheckerState createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> {
  late LoggerService logger;

  @override
  void initState() {
    super.initState();
    logger = LoggerService();
    logger.initializeLogFile();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: checkForUpdate(),
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Ошибка при проверке обновлений')),
          );
        } else {
          return const Login();
        }
      },
    );
  }

  Future<void> checkForUpdate() async {
    String currentVersion = '1.1.8';
    const String versionUrl = 'http://1c.sportpoint.ru:5055/tsd/version.json';

    try {
      final response = await http.get(Uri.parse(versionUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String latestVersion = data['latest_version'];
        final String apkUrl = data['apk_url'];

        if (latestVersion != currentVersion) {
          _showUpdateDialog(context, apkUrl);
        }
      } else {
        showErrorDialog(context, 'Ошибка проверки обновления. Код: ${response.statusCode}');
        await logger.error('Ошибка проверки обновления. Код: ${response.statusCode}');
      }
    } catch (e) {
      showErrorDialog(context, 'Произошла ошибка при проверке обновления: $e');
      await logger.error('Произошла ошибка при проверке обновления: $e');
    }
  }

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

  Future<void> _downloadAndInstallApk(String apkUrl) async {
    await logger.log('Начата загрузка APK');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Загрузка...'),
              ],
            ),
          ),
        );
      },
    );

    try {
      final directory = await getExternalStorageDirectory();
      final filePath = '${directory!.path}/yourapp.apk';

      final response = await http.get(Uri.parse(apkUrl));
      if (response.statusCode == 200) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Закрыть диалог загрузки
        Navigator.of(context, rootNavigator: true).pop();

        await logger.log('Начата установка APK');
        AppInstaller.installApk(filePath).then((_) {
        }).catchError((e) async {
          showErrorDialog(context, 'Произошла ошибка при установке APK: $e');
          await logger.error('Произошла ошибка при установке APK: $e');
        });
      } else {
        Navigator.of(context, rootNavigator: true).pop();
        showErrorDialog(context, 'Ошибка загрузки APK. Код ответа: ${response.statusCode}');
        await logger.error('Ошибка загрузки APK. Код ответа: ${response.statusCode}');
      }
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      showErrorDialog(context, 'Произошла ошибка при загрузке APK: $e');
      await logger.error('Произошла ошибка при загрузке APK: $e');
    }
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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