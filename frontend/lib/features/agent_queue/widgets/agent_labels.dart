import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';

/// Localized labels and colors shared by the agent dashboard screens.
extension AgentLabels on AppLocalizations {
  String intent(String? v) => switch (v) {
        'product_info' => agentIntentProductInfo,
        'account_opening' => agentIntentAccountOpening,
        'card_block' => agentIntentCardBlock,
        'loan_info' => agentIntentLoanInfo,
        'complaint' => agentIntentComplaint,
        'branch_info' => agentIntentBranchInfo,
        'handoff' => agentIntentHandoff,
        null => agentNone,
        _ => agentIntentOther,
      };

  String handoffReason(String? v) => switch (v) {
        'customer_request' => agentReasonCustomerRequest,
        'frustration' => agentReasonFrustration,
        'low_confidence' => agentReasonLowConfidence,
        'no_answer' => agentReasonNoAnswer,
        'identity_failed' => agentReasonIdentityFailed,
        'agent_review' => agentReasonAgentReview,
        null => agentNone,
        _ => agentReasonOther,
      };

  String callStatus(String v) => switch (v) {
        'active' => agentCallActive,
        'queued' => agentCallQueued,
        'with_agent' => agentCallWithAgent,
        _ => agentCallEnded,
      };

  String ticketStatus(String v) => switch (v) {
        'open' => agentTicketOpen,
        'in_progress' => agentTicketInProgress,
        'resolved' => agentTicketResolved,
        _ => agentTicketClosed,
      };

  String ticketCategory(String v) => switch (v) {
        'fees' => agentCategoryFees,
        'card' => agentCategoryCard,
        'loan' => agentCategoryLoan,
        'account' => agentCategoryAccount,
        'service_quality' => agentCategoryServiceQuality,
        'mobile_banking' => agentCategoryMobileBanking,
        'atm' => agentCategoryAtm,
        _ => agentCategoryOther,
      };

  String urgency(String v) => switch (v) {
        'low' => agentUrgencyLow,
        'medium' => agentUrgencyMedium,
        'high' => agentUrgencyHigh,
        _ => agentUrgencyCritical,
      };

  String channel(String v) => switch (v) {
        'phone' => agentChannelPhone,
        'web' => agentChannelWeb,
        'ussd' => agentChannelUssd,
        'sms' => agentChannelSms,
        _ => agentChannelWhatsapp,
      };

  String speaker(String v) => switch (v) {
        'customer' => callDetailSpeakerCustomer,
        'ai' => callDetailSpeakerAi,
        'agent' => callDetailSpeakerAgent,
        _ => callDetailSpeakerSystem,
      };
}

Color urgencyColor(String urgency) => switch (urgency) {
      'critical' => const Color(0xFFB91C1C),
      'high' => const Color(0xFFEA580C),
      'medium' => const Color(0xFFCA8A04),
      _ => const Color(0xFF15803D),
    };

IconData channelIcon(String channel) => switch (channel) {
      'phone' => Icons.call,
      'web' => Icons.chat_bubble_outline,
      'ussd' => Icons.dialpad,
      'sms' => Icons.sms_outlined,
      _ => Icons.forum_outlined,
    };

/// `83` → `1:23`, `3700` → `1:01:40`.
String formatDuration(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '$m:${two(sec)}';
}

/// Small colored label.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.icon});

  final String text;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: c), const SizedBox(width: 4)],
        Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}
