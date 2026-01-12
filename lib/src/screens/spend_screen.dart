import 'package:flutter/material.dart';

import '../config.dart';
import '../models/qris_payload.dart';
import '../services/pulse_api.dart';
import 'qr_scan_screen.dart';

class SpendScreen extends StatefulWidget {
  const SpendScreen({super.key});

  @override
  State<SpendScreen> createState() => _SpendScreenState();
}

class _SpendScreenState extends State<SpendScreen> {
  final _api = PulseApi();

  bool _paying = false;
  String? _error;
  QrisPayload? _payload;

  double get _amountMnee {
    final payload = _payload;
    if (payload == null) return 0;
    return payload.amountIdr / demoRateIdrPerMnee;
  }

  Future<void> _scan() async {
    setState(() {
      _error = null;
    });

    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (!mounted || raw == null) return;

    try {
      final payload = QrisPayload.fromQrString(raw);
      setState(() => _payload = payload);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _useDemoQr() {
    // Demo payload: MNEE Coffee Co., 25000 IDR
    const demoJson = '''
{
  "merchantName": "MNEE Coffee Co.",
  "mneeAddress": "0x742d35Cc6634C0532925a3b844Bc9e7595f00000",
  "amountIDR": 25000
}
''';
    try {
      final payload = QrisPayload.fromQrString(demoJson);
      setState(() {
        _error = null;
        _payload = payload;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _pay() async {
    final payload = _payload;
    if (payload == null) return;

    setState(() {
      _paying = true;
      _error = null;
    });

    try {
      final res = await _api.payQris(
        merchantAddress: payload.mneeAddress,
        amountIdr: payload.amountIdr,
        rateIdrPerMnee: demoRateIdrPerMnee,
      );
      if (!mounted) return;

      final txHash = res['txHash']?.toString() ?? 'OK';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paid. Tx: $txHash')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payload = _payload;

    return Scaffold(
      appBar: AppBar(title: const Text('Spend')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _paying ? null : _scan,
              icon: const Icon(Icons.qr_code_scanner_outlined),
              label: const Text('Scan QR (Simulated QRIS)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _paying ? null : _useDemoQr,
              icon: const Icon(Icons.coffee),
              label: const Text('Use Demo QR (Coffee Shop)'),
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            if (payload == null)
              const Expanded(
                child: Center(
                  child: Text(
                    'Scan a merchant QR to pay with MNEE.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          payload.merchantName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text('Merchant: ${payload.mneeAddress}'),
                        const SizedBox(height: 8),
                        Text('Amount: IDR ${payload.amountIdr}'),
                        const SizedBox(height: 8),
                        Text(
                          'Rate (demo): 1 MNEE = IDR $demoRateIdrPerMnee',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You pay: ${_amountMnee.toStringAsFixed(4)} MNEE',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: _paying ? null : _pay,
                          child: _paying
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Pay'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
