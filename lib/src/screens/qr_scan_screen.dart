import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_handled) return;

          final barcodes = capture.barcodes;
          final raw = barcodes.isEmpty ? null : barcodes.first.rawValue;
          if (raw == null || raw.isEmpty) return;

          _handled = true;
          Navigator.of(context).pop(raw);
        },
      ),
    );
  }
}
