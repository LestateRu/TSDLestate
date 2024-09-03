import 'package:flutter/material.dart';
import 'package:lestate_tsd_new/Controlers/Goods.dart';
import 'package:lestate_tsd_new/Controlers/HttpClient.dart';
import 'package:lestate_tsd_new/View/ScaningView.dart';
import 'package:lestate_tsd_new/main.dart';


class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  TextEditingController _username = TextEditingController();
  TextEditingController _password = TextEditingController();

  @override
  void initState() {
    super.initState();


  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              height: 32,
            ),
            const SizedBox(width: 10),
            const Text('Lestate TSD'),
          ],
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'Авторизация',
                  style: TextStyle(fontSize: 30),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _username,
                  decoration: const InputDecoration(labelText: 'Введите Ваш логин 1С'),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _password,
                  decoration: const InputDecoration(labelText: 'Введите Ваш пароль 1С'),
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      Httpclient.username = _username.text;
                      Httpclient.password = _password.text;
                      _showLoadingDialog();
                    });
                  },
                  child: const Text('Авторизация'),
                ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  Che
                });
              },
              child: const Text('Обновление'),
            )
              ],

            ),
          ),

        ],
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Получение данных...'),
            ],
          ),
        );
      },
    );

    _processJsonFile().then((success) {
      Navigator.pop(context);
      if (success) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ScanningView()),
        );
      } else {
        _showErrorDialog();
      }
    });
  }

  Future<bool> _processJsonFile() async {
    List<Goods> goods = await Httpclient.getGoods();
    if (goods.isEmpty) {
      return false;
    } else {
      return true;
    }
  }

  void _showErrorDialog() {
    String errorMessage = Httpclient.error.isNotEmpty ? Httpclient.error : 'Неверный логин или пароль.';
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Ошибка авторизации'),
          content: Text(errorMessage),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
}
