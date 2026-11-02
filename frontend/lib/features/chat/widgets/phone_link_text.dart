import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/l10n.dart';

/// Burundi numbers as the backend writes them (+257XXXXXXXX, spaces tolerated).
final kPhonePattern = RegExp(r'\+257(?:\s?\d){8}');

/// Message text where every phone number is a link: a tap offers "Call" (tel:) and "Copy".
class PhoneLinkText extends StatefulWidget {
  const PhoneLinkText(this.text, {super.key, this.style, this.linkColor});

  final String text;
  final TextStyle? style;
  final Color? linkColor;

  @override
  State<PhoneLinkText> createState() => _PhoneLinkTextState();
}

class _PhoneLinkTextState extends State<PhoneLinkText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    final matches = kPhonePattern.allMatches(widget.text).toList();
    if (matches.isEmpty) return SelectableText(widget.text, style: widget.style);
    final spans = <TextSpan>[];
    var at = 0;
    for (final m in matches) {
      if (m.start > at) spans.add(TextSpan(text: widget.text.substring(at, m.start)));
      final number = m.group(0)!.replaceAll(' ', '');
      final tap = TapGestureRecognizer()..onTap = () => showPhoneActions(context, number);
      _recognizers.add(tap);
      spans.add(TextSpan(
        text: m.group(0),
        recognizer: tap,
        mouseCursor: SystemMouseCursors.click,
        style: TextStyle(
          color: widget.linkColor,
          decoration: TextDecoration.underline,
          decorationColor: widget.linkColor,
          fontWeight: FontWeight.w600,
        ),
      ));
      at = m.end;
    }
    if (at < widget.text.length) spans.add(TextSpan(text: widget.text.substring(at)));
    // Text.rich (not SelectableText.rich): tap recognizers on spans only work on RichText; SelectionArea
    // keeps the answer selectable.
    return SelectionArea(child: Text.rich(TextSpan(style: widget.style, children: spans)));
  }
}

/// Bottom sheet with the number, "Call" and "Copy". On a computer without a calling app, "Call" fails:
/// the number is copied instead and the user is told why.
Future<void> showPhoneActions(BuildContext context, String number) {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  Future<void> copy(String message) async {
    await Clipboard.setData(ClipboardData(text: number));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  return showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.phone_outlined),
          title: SelectableText(number, style: Theme.of(sheet).textTheme.titleMedium),
        ),
        ListTile(
          key: const Key('phone_call'),
          leading: const Icon(Icons.call),
          title: Text(l10n.chatCallNumber),
          onTap: () async {
            Navigator.of(sheet).pop();
            var ok = false;
            try {
              ok = await launchUrl(Uri(scheme: 'tel', path: number));
            } catch (_) {
              ok = false;
            }
            if (!ok) await copy(l10n.chatCannotCall);
          },
        ),
        ListTile(
          key: const Key('phone_copy'),
          leading: const Icon(Icons.copy),
          title: Text(l10n.chatCopyNumber),
          onTap: () async {
            Navigator.of(sheet).pop();
            await copy(l10n.chatNumberCopied);
          },
        ),
      ]),
    ),
  );
}
