import 'package:flutter/material.dart';

import '../services/api_service.dart';

/// Floating launcher for the RAG support chat (KAN-112). Mounted once in
/// [AppShell] so every screen behind the sidebar gets it for free, the same
/// way [AppDrawer] is.
class RagChatLauncher extends StatefulWidget {
  const RagChatLauncher({super.key});

  @override
  State<RagChatLauncher> createState() => _RagChatLauncherState();
}

class _RagChatLauncherState extends State<RagChatLauncher> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final panelWidth = size.width < 420 ? size.width - 24 : 380.0;
    final panelHeight = size.height < 680 ? size.height - 140 : 560.0;

    return Stack(
      children: [
        if (_open)
          Positioned(
            right: 16,
            bottom: 88,
            child: _ChatPanel(
              width: panelWidth,
              height: panelHeight,
              onClose: () => setState(() => _open = false),
            ),
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'rag-chat-fab',
            backgroundColor: const Color(0xFF1A4FD6),
            tooltip: _open ? 'Close chat' : 'Ask WashNLaundry Assistant',
            onPressed: () => setState(() => _open = !_open),
            child: Icon(
              _open ? Icons.close_rounded : Icons.smart_toy_rounded,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatMessage {
  _ChatMessage({required this.role, required this.text});
  final String role; // 'user' | 'assistant'
  String text;
}

class _ChatPanel extends StatefulWidget {
  const _ChatPanel({
    required this.width,
    required this.height,
    required this.onClose,
  });

  final double width;
  final double height;
  final VoidCallback onClose;

  @override
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();

    final history = _messages
        .map((m) => {'role': m.role, 'content': m.text})
        .toList();

    late final _ChatMessage assistantMsg;
    setState(() {
      _error = null;
      _messages.add(_ChatMessage(role: 'user', text: text));
      assistantMsg = _ChatMessage(role: 'assistant', text: '');
      _messages.add(assistantMsg);
      _sending = true;
    });
    _scrollToBottom();

    try {
      await for (final token in ApiService.streamRagChat(text, history: history)) {
        setState(() => assistantMsg.text += token);
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        if (assistantMsg.text.isEmpty) _messages.remove(assistantMsg);
        _error = e is ApiException ? e.message : 'Could not reach the assistant: $e';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: widget.width,
        height: widget.height,
        color: Colors.white,
        child: Column(
          children: [
            _Header(onClose: widget.onClose),
            Expanded(
              child: _messages.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) => _Bubble(_messages[i]),
                    ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                ),
              ),
            _InputBar(
              controller: _controller,
              sending: _sending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1A4FD6),
      ),
      child: Row(
        children: [
          const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'WashNLaundry Assistant',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
            onPressed: onClose,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Text(
          'Ask about order status, customer dues, rates, or store policies.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.message);
  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF1A4FD6) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.text.isEmpty ? '…' : message.text,
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF0F172A),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !sending,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Type a message…',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: sending ? null : onSend,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF1A4FD6),
              disabledBackgroundColor: const Color(0xFFCBD5E1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
