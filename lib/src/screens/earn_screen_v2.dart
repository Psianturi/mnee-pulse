import 'package:flutter/material.dart';

import '../services/pulse_api.dart';
import '../theme.dart';
import '../widgets/pulse_widgets.dart';

class EarnScreen extends StatefulWidget {
  const EarnScreen({super.key});

  @override
  State<EarnScreen> createState() => _EarnScreenState();
}

class _EarnScreenState extends State<EarnScreen> with TickerProviderStateMixin {
  final _api = PulseApi();

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _tips = const [];
  Map<String, dynamic>? _status;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadStatus();
    _refresh();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: PulseColors.success),
              SizedBox(width: 8),
              Text('AI Scout found engagement! Tip sent.'),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _totalEarned {
    return _tips.fold<double>(
      0,
      (sum, tip) => sum + (tip['amountMNEE'] as num? ?? 0).toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _status?['mode'] == 'onchain';
    final relayerBalance = _status?['relayerMnee']?.toString() ?? '0';

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Earn',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: PulseColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          onPressed: _loading ? null : _refresh,
                          icon: AnimatedRotation(
                            turns: _loading ? 1 : 0,
                            duration: const Duration(seconds: 1),
                            child: Icon(
                              Icons.refresh,
                              color: _loading
                                  ? PulseColors.textMuted
                                  : PulseColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Get micro-tips for quality content',
                      style: TextStyle(
                        color: PulseColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Status & Balance Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GlassCard(
                  gradient: PulseColors.earnGradient,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Earned',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          StatusChip(
                            label: isOnline ? 'LIVE' : 'DRY-RUN',
                            isOnline: isOnline,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) => Transform.scale(
                              scale:
                                  _tips.isNotEmpty ? _pulseAnimation.value : 1,
                              child: child,
                            ),
                            child: Text(
                              _totalEarned.toStringAsFixed(2),
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8, left: 4),
                            child: Text(
                              'MNEE',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.account_balance_wallet,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Relayer: $relayerBalance MNEE',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Run Scout Button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: GradientButton(
                  onPressed: _loading ? null : _runScoutOnce,
                  isLoading: _loading,
                  icon: Icons.auto_awesome,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  child: const Text('Run AI Scout'),
                ),
              ),
            ),

            // Error message
            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PulseColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: PulseColors.error),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: PulseColors.error),
                    ),
                  ),
                ),
              ),

            // Section header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.history,
                      color: PulseColors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recent Tips (${_tips.length})',
                      style: const TextStyle(
                        color: PulseColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tips list
            if (_loading && _tips.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_tips.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: PulseColors.textMuted,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No tips yet',
                        style: TextStyle(
                          color: PulseColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Run the AI Scout to discover earnings!',
                        style: TextStyle(
                          color: PulseColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final tip = _tips[index];
                      final amount = tip['amountMNEE']?.toString() ?? '-';
                      final from = tip['from']?.toString() ?? 'AI';
                      final ticketId = tip['ticketId']?.toString();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TipListItem(
                          amount: amount,
                          from: from,
                          ticketId: ticketId,
                        ),
                      );
                    },
                    childCount: _tips.length,
                  ),
                ),
              ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 20),
            ),
          ],
        ),
      ),
    );
  }
}
