import 'package:flutter/material.dart';
import 'dart:io';
import 'package:lestate_tsd_new/View/Login.dart';

void main() {
  HttpOverrides.global = MyHttpOverrides(); // удалить при релизе
  runApp(MaterialApp(
    theme: ThemeData(
      primaryColor: Colors.blueGrey,
    ),
    home: const Login(),
  ));
}

// удалить при релизе
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}