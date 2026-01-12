import 'dart:async';

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
  final _contentController = TextEditingController();

  bool _loading = false;
  bool _evaluating = false;
  String? _error;
  String? _successMessage;
  Map<String, dynamic>? _lastEvaluation;
  List<Map<String, dynamic>> _tips = const [];
  Map<String, dynamic>? _status;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  DateTime? _scoutCooldownUntil;
  Timer? _cooldownTimer;

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
    _cooldownTimer?.cancel();
    _pulseController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _setScoutCooldown(Duration duration) {
    _cooldownTimer?.cancel();
    final until = DateTime.now().add(duration);
    setState(() => _scoutCooldownUntil = until);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      final u = _scoutCooldownUntil;
      if (u == null || DateTime.now().isAfter(u)) {
        t.cancel();
        setState(() => _scoutCooldownUntil = null);
      } else {
        setState(() {});
      }
    });
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

  Future<void> _evaluateContent() async {
    final content = _contentController.text.trim();
    if (content.length < 10) {
      setState(() => _error = 'Please enter at least 10 characters');
      return;
    }

    final cooldownUntil = _scoutCooldownUntil;
    if (cooldownUntil != null && DateTime.now().isBefore(cooldownUntil)) {
      return;
    }

    setState(() {
      _evaluating = true;
      _error = null;
      _successMessage = null;
      _lastEvaluation = null;
    });

    try {
      final result = await _api.evaluateContent(content: content);
      if (!mounted) return;

      final evaluation = result['evaluation'] as Map<String, dynamic>?;
      final rewarded = result['rewarded'] == true;

      setState(() => _lastEvaluation = evaluation);

      if (rewarded) {
        _setScoutCooldown(const Duration(minutes: 5));
        _contentController.clear();
        await _refresh();
        setState(() {
          _successMessage =
              '🎉 Score: ${evaluation?['score']}/10 - You earned 0.1 MNEE!';
        });
      } else {
        setState(() {
          _error =
              'Score: ${evaluation?['score']}/10 - Need 7+ to earn. ${evaluation?['reason'] ?? ''}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      if (message.contains('Anti-spam') || message.contains('(429)')) {
        _setScoutCooldown(const Duration(minutes: 5));
        setState(
          () => _error = 'Please wait a few minutes before submitting again.',
        );
      } else {
        setState(() => _error = message);
      }
    } finally {
      if (mounted) setState(() => _evaluating = false);
    }
  }

  String? get _scoutCooldownLabel {
    final until = _scoutCooldownUntil;
    if (until == null) return null;
    final remaining = until.difference(DateTime.now());
    if (remaining.isNegative) return null;
    final mm = remaining.inMinutes;
    final ss = remaining.inSeconds % 60;
    return '${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
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
    final scoutCooldown = _scoutCooldownLabel;
    final scoutDisabled = _loading || scoutCooldown != null;

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

            // AI Content Evaluation Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AI Content Scout',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: PulseColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Share quality content, earn MNEE tips',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: PulseColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _contentController,
                        maxLines: 4,
                        style: const TextStyle(color: PulseColors.textPrimary),
                        decoration: InputDecoration(
                          hintText:
                              'Paste your content, tweet, or article here...\n\nAI will score it 1-10. Score 7+ earns a tip!',
                          hintStyle: TextStyle(
                            color: PulseColors.textMuted,
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: PulseColors.cardBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: PulseColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: PulseColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFF59E0B),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GradientButton(
                        onPressed: scoutDisabled || _evaluating
                            ? null
                            : _evaluateContent,
                        isLoading: _evaluating,
                        icon: Icons.psychology,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        child: Text(
                          scoutCooldown == null
                              ? 'Evaluate with Gemini AI'
                              : 'Cooldown ($scoutCooldown)',
                        ),
                      ),
                      if (_lastEvaluation != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: PulseColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: PulseColors.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  color: ((_lastEvaluation?['score'] as num?)
                                                  ?.toDouble() ??
                                              0) >=
                                          7
                                      ? PulseColors.success
                                      : PulseColors.warning,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Last score: ${_lastEvaluation?['score'] ?? '-'} / 10',
                                      style: const TextStyle(
                                        color: PulseColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      (_lastEvaluation?['reason']
                                                  ?.toString()
                                                  .trim()
                                                  .isNotEmpty ??
                                              false)
                                          ? _lastEvaluation!['reason']
                                              .toString()
                                          : 'No reason provided.',
                                      style: const TextStyle(
                                        color: PulseColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Success message
            if (_successMessage != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PulseColors.earnGradient.colors.first
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: PulseColors.earnGradient.colors.first,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.celebration,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

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
