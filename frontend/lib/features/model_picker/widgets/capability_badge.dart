import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';

/// Badge for one capability reported by the API. Unknown capabilities are shown as-is.
class CapabilityBadge extends StatelessWidget {
  const CapabilityBadge(this.capability, {super.key});

  final String capability;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (IconData icon, String label) = switch (capability) {
      'completion' => (Icons.notes, l10n.modelCapCompletion),
      'vision' => (Icons.image_outlined, l10n.modelCapVision),
      'audio' => (Icons.mic_none, l10n.modelCapAudio),
      'tools' => (Icons.build_outlined, l10n.modelCapTools),
      'thinking' => (Icons.psychology_alt_outlined, l10n.modelCapThinking),
      'embedding' => (Icons.scatter_plot_outlined, l10n.modelCapEmbedding),
      _ => (Icons.extension_outlined, capability),
    };
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: Key('cap_$capability'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSecondaryContainer)),
        ],
      ),
    );
  }
}
