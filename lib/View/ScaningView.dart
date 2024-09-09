import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lestate_tsd_new/Controlers/HttpClient.dart';
import 'package:lestate_tsd_new/Controlers/Goods.dart';
import 'package:shared_preferences/shared_preferences.dart';  // Добавлено

class ScanningView extends StatefulWidget {
  const ScanningView({super.key});

  @override
  State<ScanningView> createState() => _ScanningViewState();
}

class _ScanningViewState extends State<ScanningView> {
  List<Goods> goods = [];
  List<Goods> barcodeArray = [];
  List<Goods> datamatrixArray = [];
  List<Goods> noMarkingItems = [];

  // Controllers and other variables
  TextEditingController textMessageController = TextEditingController();
  final TextEditingController batchController = TextEditingController();
  final TextEditingController markingValueController = TextEditingController();
  TextEditingController textTestController = TextEditingController();
  static const EventChannel _eventChannel = EventChannel('scan_channel');
  String _scanData = "";
  String zerro = '0';
  bool _awaitingMarkingScan = false;
  Goods? _currentMarkedItem;

  @override
  void initState() {
    super.initState();
    _eventChannel.receiveBroadcastStream().listen((event) {
      _scanData = event;
      if (_awaitingMarkingScan) {
        processMarkingScan(_scanData);
      } else {
        scanning(_scanData);
      }
    });
    getResult();
    loadSavedItems();  // Загрузка сохраненных данных при запуске
  }

  Future<void> getResult() async {
    List<Goods> fetchedGoods = await Httpclient.getGoods();
    setState(() {
      goods = fetchedGoods;
    });
  }

  // Сохранение списка отсканированных товаров
  Future<void> saveItems() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> barcodeJson = barcodeArray.map((item) => jsonEncode(item.toJson())).toList();
    List<String> datamatrixJson = datamatrixArray.map((item) => jsonEncode(item.toJson())).toList();
    List<String> noMarkingJson = noMarkingItems.map((item) => jsonEncode(item.toJson())).toList();

    await prefs.setStringList('barcodeArray', barcodeJson);
    await prefs.setStringList('datamatrixArray', datamatrixJson);
    await prefs.setStringList('noMarkingItems', noMarkingJson);
  }

  // Загрузка сохраненных данных
  Future<void> loadSavedItems() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? barcodeJson = prefs.getStringList('barcodeArray');
    List<String>? datamatrixJson = prefs.getStringList('datamatrixArray');
    List<String>? noMarkingJson = prefs.getStringList('noMarkingItems');

    if (barcodeJson != null) {
      setState(() {
        barcodeArray = barcodeJson.map((item) => Goods.fromJson(jsonDecode(item))).toList();
      });
    }

    if (datamatrixJson != null) {
      setState(() {
        datamatrixArray = datamatrixJson.map((item) => Goods.fromJson(jsonDecode(item))).toList();
      });
    }

    if (noMarkingJson != null) {
      setState(() {
        noMarkingItems = noMarkingJson.map((item) => Goods.fromJson(jsonDecode(item))).toList();
      });
    }
  }

  void scanning(String scanData) async {
    if (scanData.length == 12) {
      scanData = '0' + scanData;
    }

    if (scanData.length == 13) {
      Goods? foundItem = goods.firstWhere((item) => item.barcode == scanData);

      if (foundItem != null) {
        textTestController.text = foundItem.marking.toString();
        if (foundItem.marking == true) {
          setState(() {
            _awaitingMarkingScan = true;
            _currentMarkedItem = foundItem;
          });
          textMessageController.text = "Отсканируйте маркировку для артикула: ${foundItem.vendorCode}";
        } else {
          setState(() {
            textMessageController.text = foundItem.vendorCode;
            batchController.text = foundItem.batch.toString();
            barcodeArray.insert(0, foundItem);
            saveItems();  // Сохранение после добавления
          });
        }
      } else {
        showError();
      }
    } else {
      String newScanData = scanData.substring(3, 16);
      Goods? foundItem2 = goods.firstWhere((item) => item.barcode == newScanData);

      if (foundItem2 != null) {
        if (datamatrixArray.any((item) => item.dataMatrix == scanData)) {
          showDuplicateMarkingError();
        } else {
          Goods newItem = Goods(
            barcode: foundItem2.barcode,
            vendorCode: foundItem2.vendorCode,
            batch: foundItem2.batch,
            marking: foundItem2.marking,
            dataMatrix: scanData,
            count: foundItem2.count,
          );
          setState(() {
            textMessageController.text = foundItem2.vendorCode;
            batchController.text = foundItem2.batch.toString();
            barcodeArray.insert(0, newItem);
            datamatrixArray.insert(0, newItem);
            saveItems();  // Сохранение после добавления
          });
        }
      } else {
        showError();
      }
    }
  }

  void processMarkingScan(String scanData) {
    if (_currentMarkedItem != null) {
      if (scanData.length >= 20 &&
          scanData.contains(_currentMarkedItem!.barcode)) {
        if (datamatrixArray.any((item) => item.dataMatrix == scanData)) {
          showDuplicateMarkingError();
        } else {
          Goods newItem = Goods(
            barcode: _currentMarkedItem!.barcode,
            vendorCode: _currentMarkedItem!.vendorCode,
            batch: _currentMarkedItem!.batch,
            marking: _currentMarkedItem!.marking,
            dataMatrix: scanData,
            count: _currentMarkedItem!.count,
          );
          setState(() {
            textMessageController.text = _currentMarkedItem!.vendorCode;
            batchController.text = _currentMarkedItem!.batch.toString();
            barcodeArray.insert(0, newItem);
            datamatrixArray.insert(0, newItem);
            _awaitingMarkingScan = false;
            _currentMarkedItem = null;
          });
        }
      } else {
        showInvalidMarkingError();
      }
    }
  }

  void showInvalidMarkingError() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Ошибка'),
          content: const Text('Неверный код маркировки. Попробуйте снова.'),
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

  void showDuplicateMarkingError() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Ошибка'),
          content: const Text('Эта маркировка уже была отсканирована.'),
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

  void showError() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Ошибка'),
          content: Text(Httpclient.error),
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

  void sendResult() {
    setState(() {
      textMessageController.text = 'Данные отправлены!';
    });
  }

  Future<void> onButtonClicked(String comment) async {
    var itemStrings = barcodeArray
        .map((item) => {'barcode': item.barcode, 'count': item.count})
        .toList();
    var itemStringsMatrix = datamatrixArray
        .map((item) => {'barcode': item.barcode, 'datamatrix': item.dataMatrix})
        .toList();
    var body = {
      'barcodeArray': itemStrings,
      'datamatrixArray': itemStringsMatrix,
      'comment': comment
    };
    String combinedString = jsonEncode(body);

    await Httpclient.setMovementosGoods(combinedString);

    if (Httpclient.result) {
      sendResult();
      setState(() {
        barcodeArray.clear();
        datamatrixArray.clear();
        noMarkingItems.clear();
      });
    }
  }

  void deleteLastScannedItem() {
    setState(() {
      if (barcodeArray.isNotEmpty) {
        Goods lastItem = barcodeArray.removeAt(0);

        // Если у элемента есть DataMatrix код, удаляем его также из datamatrixArray
        if (lastItem.dataMatrix != null && lastItem.dataMatrix!.isNotEmpty) {
          datamatrixArray
              .removeWhere((item) => item.dataMatrix == lastItem.dataMatrix);
        }

        // Удаляем также из списка noMarkingItems, если элемент был без маркировки
        noMarkingItems.removeWhere((item) => item.barcode == lastItem.barcode);
      }
    });
  }

  void handleNoMarking() {
    if (_currentMarkedItem != null) {
      Goods newItem = Goods(
        barcode: _currentMarkedItem!.barcode,
        vendorCode: _currentMarkedItem!.vendorCode,
        batch: _currentMarkedItem!.batch,
        marking: _currentMarkedItem!.marking,
        dataMatrix: 'Нет маркировки',
        count: _currentMarkedItem!.count,
      );
      setState(() {
        textMessageController.text = _currentMarkedItem!.vendorCode;
        batchController.text = _currentMarkedItem!.batch.toString();
        barcodeArray.insert(0, newItem);
        datamatrixArray.insert(0, newItem);
        noMarkingItems.add(newItem);
        _awaitingMarkingScan = false;
        _currentMarkedItem = null;
      });
    }
  }

  Future<void> showSendDialog() async {
    TextEditingController commentController = TextEditingController();
    FocusNode commentFocusNode = FocusNode();
    bool isCommentEmpty = false;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Wrap(
                children: <Widget>[
                  const ListTile(
                    title: Text(
                      'Подтверждение отправки',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Общее кол-во товаров: ${barcodeArray.length}'),
                        const SizedBox(height: 10),
                        TextField(
                          controller: commentController,
                          focusNode: commentFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Введите комментарий',
                            errorText: isCommentEmpty
                                ? 'Комментарий обязателен'
                                : null,
                            errorStyle: const TextStyle(color: Colors.red),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color:
                                    isCommentEmpty ? Colors.red : Colors.blue,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color:
                                    isCommentEmpty ? Colors.red : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            TextButton(
                              child: const Text('Нет'),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            TextButton(
                              child: const Text('Да'),
                              onPressed: () {
                                if (commentController.text.isEmpty) {
                                  setState(() {
                                    isCommentEmpty = true;
                                  });
                                  commentFocusNode.requestFocus();
                                } else {
                                  Navigator.of(context).pop();
                                  onButtonClicked(commentController.text);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
          Column(
            children: [
              TextField(
                controller: textMessageController,
                readOnly: true,
                textAlign: TextAlign.center,
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Общее кол-во товаров: ${barcodeArray.length}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: barcodeArray.length,
                  itemBuilder: (BuildContext context, int index) {
                    Goods item = barcodeArray[index];
                    bool isMarked = item.marking &&
                        item.dataMatrix != null &&
                        item.dataMatrix != 'Нет маркировки';
                    bool noMarking = noMarkingItems.contains(item);
                    return ListTile(
                      leading: Text('${index + 1}'),
                      title: Text('Артикул: ${item.vendorCode}'),
                      subtitle: Text('Характеристика: ${item.batch}'),
                      trailing: item.marking
                          ? Icon(
                              isMarked
                                  ? Icons.check_circle
                                  : noMarking
                                      ? Icons.cancel
                                      : Icons.cancel,
                              color: isMarked ? Colors.green : Colors.red,
                            )
                          : null,
                      onTap: isMarked || !item.marking
                          ? null
                          : () {
                              setState(() {
                                _awaitingMarkingScan = true;
                                _currentMarkedItem = item;
                              });
                            },
                    );
                  },
                ),
              ),
              DropdownButton<String>(
                hint: const Text('Действия'),
                items: const [
                  DropdownMenuItem<String>(
                    value: 'send',
                    child: Text('Отправить'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'clear',
                    child: Text('Очистить'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'del',
                    child: Text('Удалить товар'),
                  ),
                ],
                onChanged: (String? value) {
                  if (value == 'send') {
                    showSendDialog();
                  } else if (value == 'clear') {
                    setState(() {
                      barcodeArray.clear();
                      datamatrixArray.clear();
                      noMarkingItems.clear();
                    });
                  } else if (value == 'del') {
                    deleteLastScannedItem();
                  }
                },
              ),
            ],
          ),
          Positioned(
            bottom: 16.0,
            right: 16.0,
            child: Text(
              'Версия: 1.1.5',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          if (_awaitingMarkingScan)
            Center(
              child: Container(
                color: Colors.black54,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Отсканируйте маркировку для: ${_currentMarkedItem?.vendorCode}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: handleNoMarking,
                      child: const Text('Нет маркировки (QR)'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
