import 'dart:math';

import 'package:flutter/material.dart';

import '../bloc/call_bloc.dart';

/// Big visual cue of the call phase. Each phase has its own key
/// (`call_indicator_<phase>`) so tests and screen readers can tell them apart.
class CallStatusIndicator extends StatelessWidget {
  const CallStatusIndicator({super.key, required this.phase});

  final CallPhase phase;

  static const size = 140.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final key = Key('call_indicator_${phase.name}');
    final child = switch (phase) {
      CallPhase.listening => _Pulse(key: key, color: scheme.error, icon: Icons.mic),
      CallPhase.thinking || CallPhase.connecting => SizedBox(
          key: key,
          width: size * 0.6,
          height: size * 0.6,
          child: CircularProgressIndicator(strokeWidth: 6, color: scheme.primary),
        ),
      CallPhase.speaking => _Wave(key: key, color: scheme.primary),
      CallPhase.handedOff => _Disc(key: key, color: scheme.tertiary, icon: Icons.support_agent),
      CallPhase.ended => _Disc(key: key, color: scheme.outline, icon: Icons.call_end),
      CallPhase.error => _Disc(key: key, color: scheme.error, icon: Icons.error_outline),
      CallPhase.ready => _Disc(key: key, color: scheme.primary, icon: Icons.mic_none),
      CallPhase.idle => _Disc(key: key, color: scheme.primary, icon: Icons.call),
    };
    return SizedBox(width: size, height: size, child: Center(child: child));
  }
}

class _Disc extends StatelessWidget {
  const _Disc({super.key, required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: CallStatusIndicator.size * 0.8,
        height: CallStatusIndicator.size * 0.8,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(icon, size: 56, color: color),
      );
}

/// Pulsing ring while the microphone records.
class _Pulse extends StatefulWidget {
  const _Pulse({super.key, required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          return Stack(alignment: Alignment.center, children: [
            Container(
              width: CallStatusIndicator.size * (0.6 + 0.4 * t),
              height: CallStatusIndicator.size * (0.6 + 0.4 * t),
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withValues(alpha: 0.25 * (1 - t))),
            ),
            Container(
              width: CallStatusIndicator.size * 0.6,
              height: CallStatusIndicator.size * 0.6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
              child: Icon(widget.icon, size: 48, color: Colors.white),
            ),
          ]);
        },
      );
}

/// Moving bars while Kabangutsi (or the agent) speaks.
class _Wave extends StatefulWidget {
  const _Wave({super.key, required this.color});

  final Color color;

  @override
  State<_Wave> createState() => _WaveState();
}

class _WaveState extends State<_Wave> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 5; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 12,
                height: 20 + 60 * (0.5 + 0.5 * sin(2 * pi * (_c.value + i / 5))),
                decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(6)),
              ),
          ],
        ),
      );
}
