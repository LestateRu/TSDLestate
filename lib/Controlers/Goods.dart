class Goods {
  final String vendorCode;
  final bool marking;
  final String barcode;
  final String batch;
  String dataMatrix ='';
  int count = 1;



  Goods({
    required this.vendorCode,
    required this.marking,
    required this.barcode,
    required this.batch,
    required this.dataMatrix,
    required this.count,
  });

  factory Goods.fromJson(Map<String, dynamic> json) {
    return Goods(
      vendorCode: json['vendorCode'],
      marking: json['marking'],
      barcode: json['barcode'],
      batch: json['batch'],
      dataMatrix: '',
      count: 1
    );
  }
}