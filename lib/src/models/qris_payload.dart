import 'dart:convert';

class QrisPayload {
  const QrisPayload({
    required this.merchantName,
    required this.mneeAddress,
    required this.amountUSD,
    this.isDemo = false,
  });

  final String merchantName;
  final String mneeAddress;
  final double amountUSD;
  final bool isDemo;

  static QrisPayload fromQrString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('QR payload must be a JSON object');
    }

    final merchantName = decoded['merchantName'];
    final mneeAddress = decoded['mneeAddress'];
    // Support both amountUSD and legacy amountIDR
    final amountUSD = decoded['amountUSD'] ?? (decoded['amountIDR'] != null ? (decoded['amountIDR'] as num) / 16000 : null);
    final isDemo = decoded['isDemo'] == true;

    if (merchantName is! String || merchantName.trim().isEmpty) {
      throw const FormatException('merchantName is required');
    }

    if (mneeAddress is! String || mneeAddress.trim().isEmpty) {
      throw const FormatException('mneeAddress is required');
    }

    if (amountUSD is! num) {
      throw const FormatException('amountUSD must be a number');
    }

    return QrisPayload(
      merchantName: merchantName,
      mneeAddress: mneeAddress,
      amountUSD: amountUSD.toDouble(),
      isDemo: isDemo,
    );
  }
}
