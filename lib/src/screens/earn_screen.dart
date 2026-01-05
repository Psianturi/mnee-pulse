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

  @override
  void initState() {
    super.initState();
    _refresh();
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
