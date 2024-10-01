class Goods {
  String barcode;
  String vendorCode;
  String batch;
  bool marking;
  String tnvd;
  String? dataMatrix;
  int count = 1;

  Goods({
    required this.barcode,
    required this.vendorCode,
    required this.batch,
    required this.marking,
    required this.tnvd,
    this.dataMatrix,
    required this.count,
  });

  factory Goods.fromJson(Map<String, dynamic> json) {
    return Goods(
      barcode: json['barcode'],
      vendorCode: json['vendorCode'],
      batch: json['batch'],
      marking: json['marking'],
      tnvd: json['tnvd'],
      dataMatrix: json['dataMatrix'],
      count: 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'barcode': barcode,
      'vendorCode': vendorCode,
      'batch': batch,
      'marking': marking,
      'tnvd': tnvd,
      'dataMatrix': dataMatrix,
      'count': count,
    };
  }
}
