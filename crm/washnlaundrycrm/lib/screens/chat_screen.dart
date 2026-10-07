import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/sidebar_navigation.dart';

class _ChatMessage {
  _ChatMessage({required this.role, required this.text});
  final String role; // 'user' | 'assistant'
  String text;
}

/// `/chat` — the RAG support assistant (KAN-112).
///
/// Used to be a floating FAB mounted on every screen via `AppShell`
/// (`widgets/rag_chat_panel.dart`, now removed); moved into its own sidebar
/// section so it reads like the rest of the app instead of overlaying it.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
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

    final history =
        _messages.map((m) => {'role': m.role, 'content': m.text}).toList();

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
      await for (final token
          in ApiService.streamRagChat(text, history: history)) {
        setState(() => assistantMsg.text += token);
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        if (assistantMsg.text.isEmpty) _messages.remove(assistantMsg);
        _error =
            e is ApiException ? e.message : 'Could not reach the assistant: $e';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
      drawer: const AppDrawer(),
      body: AppShell(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final narrow =
                constraints.maxWidth < SidebarNavigation.contentWideBreakpoint;
            return Column(
              children: [
                _buildHeader(narrow),
                Expanded(child: _buildBody()),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Text(
                      _error!,
                      style:
                          const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                    ),
                  ),
                _buildInputBar(narrow),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(bool narrow) {
    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: narrow ? 16 : 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE4E0D8))),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF182C4F),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.smart_toy_rounded,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          const Text('Chat',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF141A24))),
          const SizedBox(width: 8),
          const Text(
            'WashNLaundry Assistant',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Ask about order status, customer dues, rates, or store policies.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(20),
          itemCount: _messages.length,
          itemBuilder: (context, i) => _Bubble(_messages[i]),
        ),
      ),
    );
  }

  Widget _buildInputBar(bool narrow) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: narrow ? 16 : 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE4E0D8))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_sending,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Type a message…',
                    hintStyle:
                        const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE4E0D8)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE4E0D8)),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _sending ? null : _send,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF182C4F),
                  disabledBackgroundColor: const Color(0xFFD9D5CB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded,
                        size: 16, color: Colors.white),
              ),
            ],
          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF182C4F) : const Color(0xFFF1EFEA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.text.isEmpty ? '…' : message.text,
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF141A24),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
