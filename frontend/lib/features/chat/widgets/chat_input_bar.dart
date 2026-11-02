import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/l10n.dart';
import '../../../data/repositories/repositories.dart';

const _maxImageBytes = 10 * 1024 * 1024;

/// Text field + attach image + send. When [secret] is true (backend asked for a
/// PIN or date of birth) the field is masked and the text is cleared right after sending.
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.enabled,
    required this.secret,
    required this.expectedInput,
    required this.onSend,
    required this.onImage,
    this.onScanDocument,
  });

  final bool enabled;
  final bool secret;
  final String expectedInput;
  final ValueChanged<String> onSend;
  final void Function(FileUpload image, String? text) onImage;

  /// Opens the document scanner (F17) for this conversation.
  final VoidCallback? onScanDocument;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();

  @override
  void didUpdateWidget(ChatInputBar old) {
    super.didUpdateWidget(old);
    if (old.secret != widget.secret) _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    _controller.clear();
    widget.onSend(text);
  }

  Future<void> _pickImage() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > _maxImageBytes) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.chatImageTooLarge)));
      return;
    }
    final name = file.name.isEmpty ? 'image.jpg' : file.name;
    final lower = name.toLowerCase();
    final mime = file.mimeType ??
        (lower.endsWith('.png')
            ? 'image/png'
            : lower.endsWith('.webp')
                ? 'image/webp'
                : 'image/jpeg');
    final text = _controller.text.trim();
    _controller.clear();
    widget.onImage(FileUpload(bytes: bytes, filename: name, mime: mime), text.isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pin = widget.expectedInput == 'pin';
    final hint = !widget.secret
        ? l10n.chatInputHint
        : pin
            ? l10n.chatPinHint
            : l10n.chatDobHint;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            IconButton(
              key: const Key('chat_attach'),
              tooltip: l10n.attachImage,
              icon: const Icon(Icons.image_outlined),
              onPressed: widget.enabled && !widget.secret ? _pickImage : null,
            ),
            if (widget.onScanDocument != null)
              IconButton(
                key: const Key('chat_scan_document'),
                tooltip: l10n.docScanTitle,
                icon: const Icon(Icons.document_scanner_outlined),
                onPressed: widget.enabled && !widget.secret ? widget.onScanDocument : null,
              ),
            Expanded(
              child: TextField(
                key: const Key('chat_input'),
                controller: _controller,
                enabled: widget.enabled,
                obscureText: widget.secret,
                enableSuggestions: !widget.secret,
                autocorrect: !widget.secret,
                keyboardType: pin
                    ? TextInputType.number
                    : widget.secret
                        ? TextInputType.datetime
                        : TextInputType.text,
                inputFormatters: pin ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)] : null,
                textInputAction: TextInputAction.send,
                minLines: 1,
                maxLines: widget.secret ? 1 : 4,
                maxLength: widget.secret ? null : 4000,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                decoration: InputDecoration(
                  hintText: hint,
                  isDense: true,
                  prefixIcon: widget.secret ? const Icon(Icons.lock_outline) : null,
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              key: const Key('chat_send'),
              tooltip: l10n.send,
              icon: const Icon(Icons.send),
              onPressed: widget.enabled ? _send : null,
            ),
          ],
        ),
      ),
    );
  }
}
