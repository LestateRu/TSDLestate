import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:lestate_tsd_new/Controlers/Goods.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';

class Httpclient {
  static String username = '', password = '', postGUID = '', error = '';
  static bool result = false;

  static Future<List<Goods>> getGoods() async {
    String basicAuth = 'Basic ' + base64Encode(utf8.encode('$username:$password'));

    List<Goods> goods = [];

    try {
      final response = await http.get(
        Uri.parse('https://still-ghoul-star.ngrok-free.app/test_retail_niyazi/hs/apitsd/barcodes'),
        headers: {HttpHeaders.authorizationHeader: basicAuth},
      );

      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/barcodes.zip';

        // Write the ZIP file to disk
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Read the ZIP file
        final bytes = file.readAsBytesSync();
        final archive = ZipDecoder().decodeBytes(bytes);

        // Find and read the JSON file from the archive
        for (final file in archive) {
          if (file.name.endsWith('.json')) {
            final jsonContent = utf8.decode(file.content as List<int>);
            final List<dynamic> data = json.decode(jsonContent);
            final goods = data.map((item) => Goods.fromJson(item)).toList();

            return goods;
          }
        }
        // Handle the case where no JSON file is found
        error = 'JSON файл не найден в архиве.';
      } else if (response.statusCode == 401) {
        error = 'Неверный логин или пароль';
      }
      else {
        error = 'Ошибка сервера: ${response.statusCode}';
      }
    } on SocketException catch (e) {
      error = 'Ошибка сети: ${e.message}';
    } catch (e) {
      error = 'Неизвестная ошибка: ${e.toString()}';
    }
    return goods;
  }

  static Future<void> setMovementosGoods(String to1c) async {
    String basicAuth = 'Basic ' + base64Encode(utf8.encode('$username:$password'));

    try {
      final response = await http.post(
        Uri.parse('https://still-ghoul-star.ngrok-free.app/test_retail_niyazi/hs/apitsd/data'),
        headers: {
          HttpHeaders.authorizationHeader: basicAuth,
          HttpHeaders.contentTypeHeader: 'application/json',
        },
        body: to1c,
      );

      if (response.statusCode == 200) {
        result = true;
      } else {
        error = 'Ошибка сервера при отправке данных: ${response.statusCode}';
      }
    } on SocketException catch (e) {
      error = 'Ошибка сети при отправке данных: ${e.message}';
    } catch (e) {
      error = 'Неизвестная ошибка при отправке данных: ${e.toString()}';
    }
  }
}