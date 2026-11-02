import 'package:equatable/equatable.dart';

import 'json.dart';

class IntentCount extends Equatable {
  const IntentCount(this.intent, this.count);

  final String intent;
  final int count;

  @override
  List<Object?> get props => [intent, count];
}

/// `Stats` of ws_events.json (F12).
class Stats extends Equatable {
  const Stats({
    required this.periodStart,
    required this.totalCalls,
    required this.resolvedByAi,
    required this.resolvedByAgent,
    required this.aiResolutionRate,
    required this.avgWaitSeconds,
    required this.queueLength,
    required this.activeCalls,
    required this.openTickets,
    required this.topIntents,
    required this.byChannel,
    required this.byLang,
    required this.updatedAt,
  });

  factory Stats.fromJson(Json j) => Stats(
        periodStart: parseTs(j['period_start']),
        totalCalls: j['total_calls'] as int,
        resolvedByAi: j['resolved_by_ai'] as int,
        resolvedByAgent: j['resolved_by_agent'] as int,
        aiResolutionRate: toDouble(j['ai_resolution_rate']),
        avgWaitSeconds: toDouble(j['avg_wait_seconds']),
        queueLength: j['queue_length'] as int,
        activeCalls: j['active_calls'] as int,
        openTickets: j['open_tickets'] as int,
        topIntents: (j['top_intents'] as List)
            .map((e) => IntentCount((e as Json)['intent'] as String, e['count'] as int))
            .toList(),
        byChannel: (j['by_channel'] as Json).map((k, v) => MapEntry(k, v as int)),
        byLang: (j['by_lang'] as Json).map((k, v) => MapEntry(k, v as int)),
        updatedAt: parseTs(j['updated_at']),
      );

  final DateTime periodStart;
  final int totalCalls;
  final int resolvedByAi;
  final int resolvedByAgent;
  final double aiResolutionRate;
  final double avgWaitSeconds;
  final int queueLength;
  final int activeCalls;
  final int openTickets;
  final List<IntentCount> topIntents;
  final Map<String, int> byChannel;
  final Map<String, int> byLang;
  final DateTime updatedAt;

  Json toJson() => {
        'period_start': tsOf(periodStart),
        'total_calls': totalCalls,
        'resolved_by_ai': resolvedByAi,
        'resolved_by_agent': resolvedByAgent,
        'ai_resolution_rate': aiResolutionRate,
        'avg_wait_seconds': avgWaitSeconds,
        'queue_length': queueLength,
        'active_calls': activeCalls,
        'open_tickets': openTickets,
        'top_intents': topIntents.map((i) => {'intent': i.intent, 'count': i.count}).toList(),
        'by_channel': byChannel,
        'by_lang': byLang,
        'updated_at': tsOf(updatedAt),
      };

  @override
  List<Object?> get props => [periodStart, totalCalls, resolvedByAi, resolvedByAgent, aiResolutionRate, avgWaitSeconds, queueLength, activeCalls, openTickets, topIntents, byChannel, byLang, updatedAt];
}
