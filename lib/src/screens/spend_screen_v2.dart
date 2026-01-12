import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/qris_payload.dart';
import '../services/pulse_api.dart';
import '../theme.dart';
import '../widgets/pulse_widgets.dart';
import 'qr_scan_screen.dart';

class SpendScreen extends StatefulWidget {
  const SpendScreen({super.key});

  @override
  State<SpendScreen> createState() => _SpendScreenState();
}

class _SpendScreenState extends State<SpendScreen>
    with SingleTickerProviderStateMixin {
  final _api = PulseApi();

  bool _paying = false;
  bool _loadingDemoQr = false;
  String? _error;
  String? _successTitle;
  String? _successDetail;
  String? _successTicketId;
  bool _successOnchain = false;
  QrisPayload? _payload;

  late AnimationController _checkController;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  double get _amountMnee {
    final payload = _payload;
    if (payload == null) return 0;
    // 1 MNEE = 1 USD (stablecoin)
    return payload.amountUSD;
  }

  Future<void> _scan() async {
    setState(() {
      _error = null;
      _successTitle = null;
      _successDetail = null;
      _successTicketId = null;
      _successOnchain = false;
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

  Future<void> _useDemoQr() async {
    setState(() {
      _loadingDemoQr = true;
      _error = null;
      _successTitle = null;
      _successDetail = null;
      _successTicketId = null;
      _successOnchain = false;
    });

    try {
      final demo = await _api.getDemoQris();
      if (!mounted) return;

      final payload = QrisPayload.fromQrString(jsonEncode(demo));
      setState(() => _payload = payload);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingDemoQr = false);
    }
  }

  Future<void> _pay({bool forceReal = false}) async {
    final payload = _payload;
    if (payload == null) return;

    setState(() {
      _paying = true;
      _error = null;
      _successTitle = null;
      _successDetail = null;
      _successTicketId = null;
      _successOnchain = false;
    });

    try {
      final res = await _api.payQris(
        merchantAddress: payload.mneeAddress,
        amountUSD: payload.amountUSD,
        isDemo: payload.isDemo,
        forceReal: forceReal,
      );
      if (!mounted) return;

      final ticketId = res['ticketId']?.toString() ?? 'OK';
      final mode = res['mode']?.toString() ?? '';
      _checkController.forward(from: 0);
      setState(() {
        final onchain = mode != 'dry-run';
        _successOnchain = onchain;
        _successTicketId = ticketId;
        if (!onchain) {
          _successTitle = 'Demo Payment Success!';
          _successDetail = 'Ticket created (simulated).';
        } else {
          _successTitle = 'Real Payment Success!';
          _successDetail = 'Transaction hash (Ethereum mainnet).';
        }
        _payload = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  Future<void> _openEtherscanTx(String txHash) async {
    final uri = Uri.parse('https://etherscan.io/tx/$txHash');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Etherscan')),
      );
    }
  }

  void _clearPayload() {
    setState(() {
      _payload = null;
      _error = null;
      _successTitle = null;
      _successDetail = null;
      _successTicketId = null;
      _successOnchain = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final payload = _payload;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Spend',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: PulseColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: PulseColors.spendGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Pay with MNEE via QRIS',
                style: TextStyle(
                  color: PulseColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),

              // Scan buttons
              GradientButton(
                onPressed: _paying ? null : _scan,
                icon: Icons.qr_code_scanner,
                gradient: PulseColors.spendGradient,
                child: const Text('Scan QR Code'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: (_paying || _loadingDemoQr) ? null : _useDemoQr,
                icon: const Icon(Icons.coffee),
                label: const Text('Use Demo QR (Coffee Shop)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PulseColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),

              // Error message
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: PulseColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: PulseColors.error),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: PulseColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: PulseColors.error),
                        ),
                      ),
                    ],
                  ),
                ),

              // Success message
              if (_successTitle != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: PulseColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: PulseColors.success),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: _checkController,
                          curve: Curves.elasticOut,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: PulseColors.success,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _successTitle!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: PulseColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_successDetail != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _successDetail!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: PulseColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (_successTicketId != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: PulseColors.bgCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: PulseColors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  _successTicketId!,
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(
                                    color: PulseColors.success,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Copy',
                                onPressed: () =>
                                    _copyToClipboard(_successTicketId!),
                                icon: const Icon(
                                  Icons.copy,
                                  color: PulseColors.success,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_successOnchain &&
                          (_successTicketId ?? '').startsWith('0x')) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () =>
                              _openEtherscanTx(_successTicketId!.trim()),
                          icon: const Icon(
                            Icons.open_in_new,
                            color: PulseColors.success,
                            size: 18,
                          ),
                          label: const Text(
                            'View on Etherscan',
                            style: TextStyle(color: PulseColors.success),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // Payment card
              Expanded(
                child: payload == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: PulseColors.bgCard,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.qr_code_2,
                                size: 64,
                                color: PulseColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Scan a merchant QR',
                              style: TextStyle(
                                color: PulseColors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                            const Text(
                              'to pay with MNEE',
                              style: TextStyle(
                                color: PulseColors.textMuted,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GlassCard(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: IntrinsicHeight(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // Merchant header
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              gradient:
                                                  PulseColors.spendGradient,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.store,
                                              color: Colors.white,
                                              size: 28,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  payload.merchantName,
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        PulseColors.textPrimary,
                                                  ),
                                                ),
                                                const Text(
                                                  'Merchant',
                                                  style: TextStyle(
                                                    color:
                                                        PulseColors.textMuted,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: _clearPayload,
                                            icon: const Icon(
                                              Icons.close,
                                              color: PulseColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),

                                      // Address
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: PulseColors.bgDark,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.account_balance_wallet,
                                              size: 16,
                                              color: PulseColors.textMuted,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                payload.mneeAddress,
                                                style: const TextStyle(
                                                  color:
                                                      PulseColors.textSecondary,
                                                  fontSize: 12,
                                                  fontFamily: 'monospace',
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 20),

                                      // Amount details
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Amount',
                                            style: TextStyle(
                                              color: PulseColors.textSecondary,
                                            ),
                                          ),
                                          Text(
                                            '\$${payload.amountUSD.toStringAsFixed(2)} USD',
                                            style: const TextStyle(
                                              color: PulseColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Rate',
                                            style: TextStyle(
                                              color: PulseColors.textSecondary,
                                            ),
                                          ),
                                          const Text(
                                            '1 MNEE = 1 USD',
                                            style: TextStyle(
                                              color: PulseColors.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(
                                        height: 32,
                                        color: PulseColors.bgCardLight,
                                      ),

                                      // You pay
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'You Pay',
                                            style: TextStyle(
                                              color: PulseColors.textSecondary,
                                              fontSize: 16,
                                            ),
                                          ),
                                          MneeAmountDisplay(
                                            amount:
                                                _amountMnee.toStringAsFixed(4),
                                            large: true,
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 20),

                                      const Spacer(),

                                      // Demo Payment Button
                                      GradientButton(
                                        onPressed: _paying
                                            ? null
                                            : () => _pay(forceReal: false),
                                        isLoading: _paying,
                                        icon: Icons.play_circle_outline,
                                        gradient: PulseColors.spendGradient,
                                        child: Text(
                                          'Demo Pay ${_amountMnee.toStringAsFixed(4)} MNEE',
                                        ),
                                      ),

                                      const SizedBox(height: 12),

                                      // Real Blockchain Payment Button
                                      GradientButton(
                                        onPressed: _paying
                                            ? null
                                            : () => _pay(forceReal: true),
                                        isLoading: _paying,
                                        icon: Icons.currency_bitcoin,
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF22C55E),
                                            Color(0xFF10B981)
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        child: Text(
                                          '🔗 Real Tx (On-chain) ${_amountMnee.toStringAsFixed(4)} MNEE',
                                        ),
                                      ),

                                      const SizedBox(height: 8),
                                      const Text(
                                        'Real Tx uses ETH gas & MNEE tokens',
                                        style: TextStyle(
                                          color: PulseColors.textMuted,
                                          fontSize: 11,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
