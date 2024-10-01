import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lestate_tsd_new/Controlers/LoggerService.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lestate_tsd_new/Controlers/HttpClient.dart';
import 'package:lestate_tsd_new/Controlers/Goods.dart';

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
  late File saveFile; // Файл для сохранения данных
  late LoggerService logger;

  @override
  void initState() {
    super.initState();
    logger = LoggerService();
    logger.initializeLogFile();

    _eventChannel.receiveBroadcastStream().listen((event) {
      _scanData = event;
      if (_awaitingMarkingScan) {
        processMarkingScan(_scanData);
      } else {
        scanning(_scanData);
      }
    });
    getResult();
    initializeFile(); // Инициализация файла
  }

  Future<void> getResult() async {
    List<Goods> fetchedGoods = await Httpclient.getGoods();
    setState(() {
      goods = fetchedGoods;
    });
    await logger.log('ШК из 1С получены');
  }

  // Инициализация файла для сохранения данных
  Future<void> initializeFile() async {
    final directory = await getApplicationDocumentsDirectory();
    saveFile = File('${directory.path}/save.json');

    if (!(await saveFile.exists())) {
      await saveFile.create(); // Создаем файл, если его нет
      await saveFile.writeAsString(jsonEncode({
        'barcodeArray': [],
        'datamatrixArray': [],
        'noMarkingItems': [],
      }));
    }

    loadSavedItems(); // Загружаем сохранённые элементы, если есть
  }

  // Загрузка данных из файла
  Future<void> loadSavedItems() async {
    String content = await saveFile.readAsString();
    if (content.isNotEmpty) {
      Map<String, dynamic> jsonData = jsonDecode(content);

      setState(() {
        barcodeArray = (jsonData['barcodeArray'] as List)
            .map((item) => Goods.fromJson(item))
            .toList();
        datamatrixArray = (jsonData['datamatrixArray'] as List)
            .map((item) => Goods.fromJson(item))
            .toList();
        noMarkingItems = (jsonData['noMarkingItems'] as List)
            .map((item) => Goods.fromJson(item))
            .toList();
      });
      await logger
          .log('Сохраненные данные предидущего сканирования - загружены');
    }
  }

  // Сохранение данных в файл
  Future<void> saveItems() async {
    Map<String, dynamic> jsonData = {
      'barcodeArray': barcodeArray.map((item) => item.toJson()).toList(),
      'datamatrixArray': datamatrixArray.map((item) => item.toJson()).toList(),
      'noMarkingItems': noMarkingItems.map((item) => item.toJson()).toList(),
    };
    await saveFile.writeAsString(jsonEncode(jsonData));
    //await logger.log('Данные сканирования сохранены');
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
          textMessageController.text =
              "Отсканируйте маркировку для артикула: ${foundItem.vendorCode}";
        } else {
          setState(() {
            textMessageController.text = foundItem.vendorCode;
            batchController.text = foundItem.batch.toString();
            barcodeArray.insert(0, foundItem);
            saveItems(); // Сохранение после добавления
          });
        }
      } else {
        showError(Httpclient.error);
      }
    } else if (scanData.length > 15) {
      String newScanData = scanData.substring(3, 16);
      if (newScanData.startsWith('290')) {
        showError("Сначала необходимо отсканировать ШК, затем маркировку");
      } else {
        Goods? foundItem2 =
            goods.firstWhere((item) => item.barcode == newScanData);

        if (foundItem2 != null) {
          if (datamatrixArray.any((item) => item.dataMatrix == scanData)) {
            showDuplicateMarkingError();
          } else {
            Goods newItem = Goods(
              barcode: foundItem2.barcode,
              vendorCode: foundItem2.vendorCode,
              batch: foundItem2.batch,
              marking: foundItem2.marking,
              tnvd: foundItem2.tnvd,
              dataMatrix: scanData,
              count: foundItem2.count,
            );
            setState(() {
              textMessageController.text = foundItem2.vendorCode;
              batchController.text = foundItem2.batch.toString();
              barcodeArray.insert(0, newItem);
              datamatrixArray.insert(0, newItem);
              saveItems(); // Сохранение после добавления
            });
          }
        } else {
          showError(Httpclient.error);
        }
      }
    } else {
      showError('Данный товар не найден!');
      await logger.log('Указанный ШК или маркировка не найдены - $scanData');
    }
  }

  void processMarkingScan(String scanData) {
    if (_currentMarkedItem != null) {
      bool tnvdTry = false;
      if (_currentMarkedItem!.tnvd.startsWith('6101') ||
          _currentMarkedItem!.tnvd.startsWith('6102') ||
          _currentMarkedItem!.tnvd.startsWith('6103') ||
          _currentMarkedItem!.tnvd.startsWith('6104') ||
          _currentMarkedItem!.tnvd.startsWith('6105') ||
          _currentMarkedItem!.tnvd.startsWith('6110') ||
          _currentMarkedItem!.tnvd.startsWith('6203') ||
          _currentMarkedItem!.tnvd.startsWith('6204') ||
          _currentMarkedItem!.tnvd.startsWith('6205') ||
          _currentMarkedItem!.tnvd.startsWith('6206') ||
          _currentMarkedItem!.tnvd.startsWith('6210') ||
          _currentMarkedItem!.tnvd.startsWith('6214') ||
          _currentMarkedItem!.tnvd.startsWith('6215') ||
          _currentMarkedItem!.tnvd.startsWith('4304000000') ||
          _currentMarkedItem!.tnvd.startsWith('6112110000') ||
          _currentMarkedItem!.tnvd.startsWith('6112120000') ||
          _currentMarkedItem!.tnvd.startsWith('6112190000') ||
          _currentMarkedItem!.tnvd.startsWith('6112200000') ||
          _currentMarkedItem!.tnvd.startsWith('611300') ||
          _currentMarkedItem!.tnvd.startsWith('6211200000') ||
          _currentMarkedItem!.tnvd.startsWith('621132') ||
          _currentMarkedItem!.tnvd.startsWith('621133') ||
          _currentMarkedItem!.tnvd.startsWith('6211390000') ||
          _currentMarkedItem!.tnvd.startsWith('621142') ||
          _currentMarkedItem!.tnvd.startsWith('621143') ||
          _currentMarkedItem!.tnvd.startsWith('621149000')) {
        tnvdTry = true;
      }
      if (scanData.length >= 20 &&
              scanData.contains(_currentMarkedItem!.barcode) ||
          scanData.length >= 20 &&
              scanData.contains('290') &&
              tnvdTry == true) {
        if (datamatrixArray.any((item) => item.dataMatrix == scanData)) {
          showDuplicateMarkingError();
        } else {
          Goods newItem = Goods(
            barcode: _currentMarkedItem!.barcode,
            vendorCode: _currentMarkedItem!.vendorCode,
            batch: _currentMarkedItem!.batch,
            marking: _currentMarkedItem!.marking,
            tnvd: _currentMarkedItem!.tnvd,
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
            saveItems();
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

  void showError(String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Ошибка'),
          content: Text(error),
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
    await logger.log('Нажата кнопка - Отправить данные');
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
      await logger.log('Данные отправлены - ${barcodeArray.length} товаров');
      setState(() {
        barcodeArray.clear();
        datamatrixArray.clear();
        noMarkingItems.clear();
      });
      await saveFile.writeAsString(jsonEncode({
        'barcodeArray': [],
        'datamatrixArray': [],
        'noMarkingItems': [],
      }));
      await logger.log('Данные Очищены после отправки');
      Httpclient.result = false;
    } else {
      showError('Отправка данных не удалась. Повторите отправку еще раз.');
    }
  }

  void clearItems() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Подтверждение'),
          content: const Text('Вы уверены, что хотите очистить все данные?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Нет'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Да'),
              onPressed: () async {
                // Очищаем данные
                setState(() {
                  barcodeArray.clear();
                  datamatrixArray.clear();
                  noMarkingItems.clear();
                });
                await saveFile.writeAsString(jsonEncode({
                  'barcodeArray': [],
                  'datamatrixArray': [],
                  'noMarkingItems': [],
                }));
                await logger.log('Нажата кнопка - Очистить все данные');

                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> deleteLastScannedItem() async {
    setState(() async {
      if (barcodeArray.isNotEmpty) {
        Goods lastItem = barcodeArray.removeAt(0);

        // Если у элемента есть DataMatrix код, удаляем его также из datamatrixArray
        if (lastItem.dataMatrix != null && lastItem.dataMatrix!.isNotEmpty) {
          datamatrixArray
              .removeWhere((item) => item.dataMatrix == lastItem.dataMatrix);
        }
        saveItems();
        await logger.log(
            'Нажата кнопка - Удалить последний отсканированный элемент - $lastItem.barcode');
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
        tnvd: _currentMarkedItem!.tnvd,
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
        saveItems();
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
                    clearItems();
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
              'v: 1.1.8t',
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
