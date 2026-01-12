import 'package:flutter/material.dart';

import '../services/pulse_api.dart';

class EarnScreen extends StatefulWidget {
  const EarnScreen({super.key});

  @override
  State<EarnScreen> createState() => _EarnScreenState();
}

class _EarnScreenState extends State<EarnScreen> {
  final _api = PulseApi();

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _tips = const [];
  Map<String, dynamic>? _status;

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _refresh();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await _api.getStatus();
      if (mounted) setState(() => _status = status);
    } catch (_) {
      // Ignore status errors, non-critical
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tips = await _api.listTips();
      setState(() => _tips = tips);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _runScoutOnce() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _api.runScoutOnce();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scout run completed')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Earn'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_status != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _status!['mode'] == 'onchain'
                                ? Icons.cloud_done
                                : Icons.cloud_off,
                            size: 20,
                            color: _status!['mode'] == 'onchain'
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Mode: ${_status!['mode']}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                      if (_status!['relayerMnee'] != null) ...[
                        const SizedBox(height: 4),
                        Text('Relayer MNEE: ${_status!['relayerMnee']}'),
                      ],
                      if (_status!['relayerEth'] != null)
                        Text('Relayer ETH: ${_status!['relayerEth']}'),
                    ],
                  ),
                ),
              ),
            if (_status != null) const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _runScoutOnce,
              child: const Text('Run AI Scout (once)'),
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: _loading && _tips.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _tips.isEmpty
                      ? const Center(child: Text('No tips yet'))
                      : ListView.separated(
                          itemCount: _tips.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final tip = _tips[index];
                            final amount = tip['amountMNEE']?.toString() ?? '-';
                            final from = tip['from']?.toString() ?? 'AI';
                            final tx = tip['txHash']?.toString();
                            return ListTile(
                              title: Text('$amount MNEE'),
                              subtitle: Text('From: $from'),
                              trailing: tx == null
                                  ? null
                                  : const Icon(Icons.open_in_new),
                              onTap: tx == null ? null : () {},
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
