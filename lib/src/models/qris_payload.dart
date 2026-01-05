import 'dart:convert';

class QrisPayload {
  const QrisPayload({
    required this.merchantName,
    required this.mneeAddress,
    required this.amountIdr,
  });

  final String merchantName;
  final String mneeAddress;
  final int amountIdr;

  static QrisPayload fromQrString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('QR payload must be a JSON object');
    }

    final merchantName = decoded['merchantName'];
    final mneeAddress = decoded['mneeAddress'];
    final amountIdr = decoded['amountIDR'];

    if (merchantName is! String || merchantName.trim().isEmpty) {
      throw const FormatException('merchantName is required');
    }

    if (mneeAddress is! String || mneeAddress.trim().isEmpty) {
      throw const FormatException('mneeAddress is required');
    }

    if (amountIdr is! num) {
      throw const FormatException('amountIDR must be a number');
    }

    return QrisPayload(
      merchantName: merchantName,
      mneeAddress: mneeAddress,
      amountIdr: amountIdr.round(),
    );
  }
}
