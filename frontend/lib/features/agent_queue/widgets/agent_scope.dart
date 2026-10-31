import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/session/agent_session_cubit.dart';
import '../../../data/models/models.dart';

/// Provides the shared [AgentSessionCubit] and builds [builder] once an agent
/// is selected (agents are loaded from `GET /v1/agents` on first use).
class AgentScope extends StatefulWidget {
  const AgentScope({super.key, required this.builder});

  final Widget Function(BuildContext context, Agent agent) builder;

  @override
  State<AgentScope> createState() => _AgentScopeState();
}

class _AgentScopeState extends State<AgentScope> {
  late final AgentSessionCubit _session = sl<AgentSessionCubit>();

  @override
  void initState() {
    super.initState();
    if (_session.state.current == null) _session.load();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _session,
      child: BlocBuilder<AgentSessionCubit, AgentSessionState>(
        builder: (context, s) {
          final agent = s.current;
          if (agent != null) return widget.builder(context, agent);
          if (s.error != null) {
            return Scaffold(
              body: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(context.l10n.agentLoadError),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: _session.load, child: Text(context.l10n.agentRetry)),
                ]),
              ),
            );
          }
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        },
      ),
    );
  }
}

/// App-bar dropdown to choose which demo agent uses the dashboard.
class AgentPicker extends StatelessWidget {
  const AgentPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AgentSessionCubit>().state;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    if (s.agents.isEmpty || s.current == null) return const SizedBox.shrink();
    IconData icon(Agent a) => a.role == 'supervisor' ? Icons.verified_user_outlined : Icons.headset_mic_outlined;
    // Narrow windows: icon-only menu so the app bar never overflows.
    if (MediaQuery.sizeOf(context).width < 720) {
      return PopupMenuButton<String>(
        key: const Key('agent_picker'),
        tooltip: s.current!.name,
        icon: Icon(icon(s.current!)),
        initialValue: s.current!.id,
        onSelected: (id) => context.read<AgentSessionCubit>().select(s.agents.firstWhere((a) => a.id == id)),
        itemBuilder: (_) => [
          for (final a in s.agents)
            PopupMenuItem(value: a.id, child: Row(children: [Icon(icon(a), size: 18), const SizedBox(width: 6), Text(a.name)])),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: const Key('agent_picker'),
          value: s.current!.id,
          dropdownColor: Theme.of(context).colorScheme.primary,
          iconEnabledColor: onPrimary,
          style: TextStyle(color: onPrimary),
          items: [
            for (final a in s.agents)
              DropdownMenuItem(value: a.id, child: Row(children: [
                Icon(icon(a), size: 18, color: onPrimary),
                const SizedBox(width: 6),
                Text(a.name),
              ])),
          ],
          onChanged: (id) => context.read<AgentSessionCubit>().select(s.agents.firstWhere((a) => a.id == id)),
        ),
      ),
    );
  }
}
