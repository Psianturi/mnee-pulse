import 'package:flutter/material.dart';

import '../theme.dart';

class Pulse extends StatefulWidget {
  const Pulse({
    super.key,
    required this.child,
    this.enabled = true,
    this.duration = const Duration(milliseconds: 1200),
    this.minScale = 1.0,
    this.maxScale = 1.04,
    this.minOpacity = 1.0,
    this.maxOpacity = 1.0,
  });

  final Widget child;
  final bool enabled;
  final Duration duration;
  final double minScale;
  final double maxScale;
  final double minOpacity;
  final double maxOpacity;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _rebuildTweens();
    _sync();
  }

  @override
  void didUpdateWidget(covariant Pulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.minScale != widget.minScale ||
        oldWidget.maxScale != widget.maxScale ||
        oldWidget.minOpacity != widget.minOpacity ||
        oldWidget.maxOpacity != widget.maxOpacity) {
      _rebuildTweens();
    }
    if (oldWidget.enabled != widget.enabled) {
      _sync();
    }
  }

  void _rebuildTweens() {
    _scale =
        Tween<double>(begin: widget.minScale, end: widget.maxScale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _opacity = Tween<double>(
      begin: widget.minOpacity,
      end: widget.maxOpacity,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  void _sync() {
    if (widget.enabled) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(scale: _scale.value, child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// Gradient card with glass morphism effect
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.gradient,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final Gradient? gradient;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient ?? PulseColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.gradient = PulseColors.primaryGradient,
    this.isLoading = false,
    this.icon,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Gradient gradient;
  final bool isLoading;
  final IconData? icon;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: isDisabled ? null : (_) => _controller.forward(),
        onTapUp: isDisabled ? null : (_) => _controller.reverse(),
        onTapCancel: isDisabled ? null : () => _controller.reverse(),
        onTap: isDisabled ? null : widget.onPressed,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isDisabled ? 0.5 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: widget.gradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: PulseColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else ...[
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                  ],
                  DefaultTextStyle(
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    child: widget.child,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Status chip with icon
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.isOnline,
  });

  final String label;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isOnline ? PulseColors.success : PulseColors.warning)
            .withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnline ? PulseColors.success : PulseColors.warning,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOnline ? PulseColors.success : PulseColors.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isOnline ? PulseColors.success : PulseColors.warning,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class MneeAmountDisplay extends StatelessWidget {
  const MneeAmountDisplay({
    super.key,
    required this.amount,
    this.label,
    this.large = false,
  });

  final String amount;
  final String? label;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Text(
            label!,
            style: const TextStyle(
              color: PulseColors.textSecondary,
              fontSize: 12,
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              amount,
              style: TextStyle(
                fontSize: large ? 32 : 24,
                fontWeight: FontWeight.bold,
                color: PulseColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'MNEE',
              style: TextStyle(
                fontSize: large ? 16 : 14,
                fontWeight: FontWeight.w600,
                color: PulseColors.secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class TipListItem extends StatelessWidget {
  const TipListItem({
    super.key,
    required this.amount,
    required this.from,
    this.ticketId,
    this.onTap,
  });

  final String amount;
  final String from;
  final String? ticketId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: PulseColors.earnGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.bolt,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '+$amount MNEE',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: PulseColors.success,
                    ),
                  ),
                  Text(
                    'From: $from',
                    style: const TextStyle(
                      fontSize: 12,
                      color: PulseColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (ticketId != null)
              Icon(
                Icons.open_in_new,
                color: PulseColors.textMuted,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
