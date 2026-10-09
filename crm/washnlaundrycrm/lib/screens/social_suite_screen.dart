import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/panel_card.dart';
import '../widgets/top_header.dart';

class SocialSuiteScreen extends StatefulWidget {
  const SocialSuiteScreen({super.key});

  @override
  State<SocialSuiteScreen> createState() => _SocialSuiteScreenState();
}

class _SocialSuiteScreenState extends State<SocialSuiteScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State caches
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _settings = {};
  Map<String, dynamic> _analytics = {};
  List<dynamic> _posts = [];
  List<dynamic> _leads = [];
  List<dynamic> _conversations = [];

  // Active DM thread state
  String? _selectedConvId;
  String _selectedConvPlatform = 'INSTAGRAM';
  String _selectedConvSender = 'Customer';
  List<dynamic> _activeMessages = [];
  bool _messagesLoading = false;
  final TextEditingController _msgInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  // Settings controllers
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _pageNameController = TextEditingController();
  final TextEditingController _igUserController = TextEditingController();
  bool _autoReplyEnabled = true;
  bool _testingConnection = false;
  String? _verifyResultMsg;
  bool? _verifySuccess;

  // New Post Dialog controllers
  final TextEditingController _postContentController = TextEditingController();
  final TextEditingController _postImageController = TextEditingController();
  String _postPlatform = 'BOTH';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _msgInputController.dispose();
    _chatScrollController.dispose();
    _tokenController.dispose();
    _pageNameController.dispose();
    _igUserController.dispose();
    _postContentController.dispose();
    _postImageController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resSettings = await ApiService.fetchMetaSettings();
      final resAnalytics = await ApiService.fetchMetaSocialAnalytics();
      final resPosts = await ApiService.fetchMetaPosts();
      final resLeads = await ApiService.fetchMetaLeads();
      final resConvs = await ApiService.fetchMetaConversations();

      setState(() {
        _settings = resSettings;
        _analytics = resAnalytics;
        _posts = resPosts;
        _leads = resLeads;
        _conversations = resConvs;

        _tokenController.text = _settings['page_access_token'] ?? '';
        _pageNameController.text = _settings['facebook_page_name'] ?? 'WashNLaundry Official';
        _igUserController.text = _settings['instagram_username'] ?? 'washnlaundry';
        _autoReplyEnabled = _settings['auto_reply_enabled'] ?? true;

        if (_conversations.isNotEmpty && _selectedConvId == null) {
          _selectConversation(_conversations.first['conversation_id'],
              _conversations.first['platform'], _conversations.first['sender_name']);
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectConversation(String convId, String platform, String sender) async {
    setState(() {
      _selectedConvId = convId;
      _selectedConvPlatform = platform;
      _selectedConvSender = sender;
      _messagesLoading = true;
    });

    try {
      final msgs = await ApiService.fetchMetaMessages(convId);
      setState(() {
        _activeMessages = msgs;
        _messagesLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messagesLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({bool useAi = false}) async {
    final text = _msgInputController.text.trim();
    if (text.isEmpty && !useAi) return;
    _msgInputController.clear();

    final cid = _selectedConvId ?? 'conv_new_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _selectedConvId = cid;
      _messagesLoading = true;
    });

    try {
      await ApiService.sendMetaReply(
        conversationId: cid,
        text: text,
        platform: _selectedConvPlatform,
        senderName: _selectedConvSender,
        useAi: useAi,
      );
      final updatedMsgs = await ApiService.fetchMetaMessages(cid);
      final updatedConvs = await ApiService.fetchMetaConversations();
      setState(() {
        _activeMessages = updatedMsgs;
        _conversations = updatedConvs;
        _messagesLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messagesLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send reply: $e')),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    try {
      await ApiService.updateMetaSettings({
        'page_access_token': _tokenController.text.trim(),
        'facebook_page_name': _pageNameController.text.trim(),
        'instagram_username': _igUserController.text.trim(),
        'auto_reply_enabled': _autoReplyEnabled,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meta credentials saved successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    }
  }

  Future<void> _verifyConnection() async {
    setState(() {
      _testingConnection = true;
      _verifyResultMsg = null;
      _verifySuccess = null;
    });
    try {
      await _saveSettings();
      final res = await ApiService.verifyMetaSettings();
      setState(() {
        _testingConnection = false;
        _verifySuccess = res['connected'] == true;
        _verifyResultMsg = res['message'] ?? 'Verified successfully';
      });
      _loadAllData();
    } catch (e) {
      setState(() {
        _testingConnection = false;
        _verifySuccess = false;
        _verifyResultMsg = 'Error: $e';
      });
    }
  }

  Future<void> _convertLeadToOrder(int leadId) async {
    try {
      final res = await ApiService.convertMetaLead(leadId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Lead converted! Order created: ${res['order_number'] ?? 'Created'}'),
            backgroundColor: const Color(0xFF0F766E),
          ),
        );
      }
      _loadAllData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to convert lead: $e')),
        );
      }
    }
  }

  void _showCreatePostDialog() {
    _postContentController.clear();
    _postImageController.clear();
    _postPlatform = 'BOTH';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Create Social Post'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Platform', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _postPlatform,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'BOTH', child: Text('Facebook & Instagram')),
                      DropdownMenuItem(value: 'INSTAGRAM', child: Text('Instagram Only')),
                      DropdownMenuItem(value: 'FACEBOOK', child: Text('Facebook Only')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => _postPlatform = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Caption / Message', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _postContentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Announce a weekend laundry discount, festival offer...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Image URL (Required for Instagram)', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _postImageController,
                    decoration: const InputDecoration(
                      hintText: 'https://example.com/wash-poster.jpg',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF182C4F)),
              onPressed: () async {
                final content = _postContentController.text.trim();
                final img = _postImageController.text.trim();
                if (content.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await ApiService.createMetaPost({
                    'platform': _postPlatform,
                    'content': content,
                    'image_url': img,
                    'status': 'PUBLISHED',
                  });
                  _loadAllData();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to publish post: $e')),
                    );
                  }
                }
              },
              child: const Text('Publish Now', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
      drawer: const AppDrawer(),
      body: AppShell(
        body: Column(
          children: [
            TopHeader(
              title: 'Social Suite',
              actionLabel: 'New Post',
              actionIcon: Icons.add,
              onActionPressed: _showCreatePostDialog,
            ),
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF182C4F),
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: const Color(0xFF182C4F),
                indicatorWeight: 3,
                tabs: const [
                  Tab(icon: Icon(Icons.analytics_outlined), text: 'Analytics'),
                  Tab(icon: Icon(Icons.forum_outlined), text: 'AI & DMs'),
                  Tab(icon: Icon(Icons.post_add_rounded), text: 'Posts & Feed'),
                  Tab(icon: Icon(Icons.campaign_outlined), text: 'Ad Leads'),
                  Tab(icon: Icon(Icons.key_outlined), text: 'API Settings'),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Error loading Social Suite: $_error',
                                  style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _loadAllData,
                                child: const Text('Retry'),
                              )
                            ],
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildAnalyticsTab(),
                            _buildChatAndDmsTab(),
                            _buildPostsTab(),
                            _buildLeadsTab(),
                            _buildApiSettingsTab(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Analytics ─────────────────────────────────────────────────────────

  Widget _buildAnalyticsTab() {
    final ov = _analytics['overview'] ?? {};
    final channels = (_analytics['channels'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStatCard('Total Reach', '${ov['total_reach'] ?? 0}', Icons.remove_red_eye_outlined, Colors.blue),
              const SizedBox(width: 16),
              _buildStatCard('Instagram Followers', '${ov['followers_instagram'] ?? 0}', Icons.camera_alt_outlined, Colors.purple),
              const SizedBox(width: 16),
              _buildStatCard('Facebook Followers', '${ov['followers_facebook'] ?? 0}', Icons.facebook_outlined, Colors.indigo),
              const SizedBox(width: 16),
              _buildStatCard('Total Ad Leads', '${ov['total_leads'] ?? 0}', Icons.group_add_outlined, Colors.teal),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: PanelCard(
                  title: 'Connected Meta Channels',
                  child: Column(
                    children: channels.map<Widget>((ch) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: ch['platform'] == 'Instagram'
                              ? Colors.purple.shade50
                              : Colors.blue.shade50,
                          child: Icon(
                            ch['platform'] == 'Instagram' ? Icons.camera_alt : Icons.facebook,
                            color: ch['platform'] == 'Instagram' ? Colors.purple : Colors.blue,
                          ),
                        ),
                        title: Text(ch['platform'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(ch['handle'] ?? ''),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${ch['followers']} Followers', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('${ch['leads']} Leads captured', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: PanelCard(
                  title: 'Meta AI Support Metrics',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        _metricRow('Total DM Inquiries', '${ov['total_dms'] ?? 0}'),
                        const Divider(),
                        _metricRow('AI Responses Dispatched', '${ov['ai_replies_sent'] ?? 0}'),
                        const Divider(),
                        _metricRow('Engagement Rate', '${ov['engagement_rate'] ?? 0}%'),
                        const Divider(),
                        _metricRow('Lead Conversion Rate', '${ov['lead_conversion_rate'] ?? 0}%'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _metricRow(String title, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF64748B))),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4E0D8)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  // ── Tab 2: AI & DMs ─────────────────────────────────────────────────────────

  Widget _buildChatAndDmsTab() {
    return Row(
      children: [
        // Thread list
        SizedBox(
          width: 320,
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFE4E0D8))),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mark_chat_unread_outlined, size: 20, color: Color(0xFF182C4F)),
                      const SizedBox(width: 8),
                      const Text('Conversations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.add_comment_outlined, size: 20),
                        tooltip: 'Simulate New DM',
                        onPressed: () {
                          _selectedConvId = 'conv_${DateTime.now().millisecondsSinceEpoch}';
                          _selectedConvSender = 'New Prospect';
                          _activeMessages = [];
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _conversations.isEmpty
                      ? const Center(child: Text('No DM threads yet'))
                      : ListView.separated(
                          itemCount: _conversations.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final conv = _conversations[i];
                            final isSel = conv['conversation_id'] == _selectedConvId;
                            return ListTile(
                              selected: isSel,
                              selectedTileColor: const Color(0xFFF1F5F9),
                              leading: CircleAvatar(
                                backgroundColor: conv['platform'] == 'INSTAGRAM'
                                    ? Colors.purple.shade50
                                    : Colors.blue.shade50,
                                child: Icon(
                                  conv['platform'] == 'INSTAGRAM' ? Icons.camera_alt : Icons.facebook,
                                  color: conv['platform'] == 'INSTAGRAM' ? Colors.purple : Colors.blue,
                                  size: 18,
                                ),
                              ),
                              title: Text(conv['sender_name'] ?? 'Customer',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                conv['last_message'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _selectConversation(
                                conv['conversation_id'],
                                conv['platform'],
                                conv['sender_name'],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1, color: Color(0xFFE4E0D8)),
        // Conversation panel
        Expanded(
          child: Container(
            color: const Color(0xFFF8F7F5),
            child: Column(
              children: [
                // Active chat header
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  color: Colors.white,
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _selectedConvPlatform == 'INSTAGRAM'
                            ? Colors.purple.shade100
                            : Colors.blue.shade100,
                        child: Text(_selectedConvSender.isNotEmpty ? _selectedConvSender[0] : 'C'),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedConvSender, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('via $_selectedConvPlatform DM', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.smart_toy, size: 16, color: Color(0xFF0369A1)),
                            SizedBox(width: 4),
                            Text('Meta AI Auto-Reply Active', style: TextStyle(color: Color(0xFF0369A1), fontSize: 12)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                // Messages body
                Expanded(
                  child: _messagesLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _activeMessages.isEmpty
                          ? const Center(
                              child: Text(
                                'No messages in this conversation.\nType below to simulate an incoming customer inquiry or reply.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              controller: _chatScrollController,
                              padding: const EdgeInsets.all(20),
                              itemCount: _activeMessages.length,
                              itemBuilder: (ctx, i) {
                                final msg = _activeMessages[i];
                                final isUser = msg['sender_type'] == 'USER';
                                final isAi = msg['sender_type'] == 'AI';
                                return Align(
                                  alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    constraints: const BoxConstraints(maxWidth: 480),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isUser
                                          ? Colors.white
                                          : isAi
                                              ? const Color(0xFF182C4F)
                                              : const Color(0xFF0F766E),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          isUser ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isAi)
                                              const Padding(
                                                padding: EdgeInsets.only(right: 6),
                                                child: Icon(Icons.smart_toy, color: Colors.cyanAccent, size: 14),
                                              ),
                                            Text(
                                              isUser
                                                  ? msg['sender_name'] ?? 'Customer'
                                                  : isAi
                                                      ? 'Meta AI'
                                                      : 'Staff Support',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isUser ? Colors.grey.shade700 : Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          msg['text'] ?? '',
                                          style: TextStyle(
                                            color: isUser ? Colors.black87 : Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
                // Message input
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgInputController,
                          decoration: const InputDecoration(
                            hintText: 'Type customer inquiry or support reply...',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onSubmitted: (_) => _sendMessage(useAi: false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        ),
                        onPressed: () => _sendMessage(useAi: true),
                        icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                        label: const Text('Meta AI Reply', style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, color: Color(0xFF182C4F)),
                        onPressed: () => _sendMessage(useAi: false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Tab 3: Posts & Feed ────────────────────────────────────────────────────

  Widget _buildPostsTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Scheduled & Published Social Posts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF182C4F)),
                onPressed: _showCreatePostDialog,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('New Post', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _posts.isEmpty
                ? const Center(child: Text('No posts yet. Click "New Post" to publish updates.'))
                : ListView.builder(
                    itemCount: _posts.length,
                    itemBuilder: (ctx, i) {
                      final p = _posts[i];
                      final isIg = p['platform'] == 'INSTAGRAM';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: isIg ? Colors.purple.shade50 : Colors.blue.shade50,
                                child: Icon(
                                  isIg ? Icons.camera_alt : Icons.facebook,
                                  color: isIg ? Colors.purple : Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(p['platform'] ?? '',
                                            style: const TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: p['status'] == 'PUBLISHED'
                                                ? Colors.green.shade100
                                                : Colors.orange.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            p['status'] ?? '',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: p['status'] == 'PUBLISHED'
                                                  ? Colors.green.shade800
                                                  : Colors.orange.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(p['content'] ?? '', style: const TextStyle(fontSize: 15)),
                                    if (p['image_url'] != null && (p['image_url'] as String).isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text('Attached Image: ${p['image_url']}',
                                            style: const TextStyle(fontSize: 12, color: Colors.blue)),
                                      ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(Icons.favorite, size: 16, color: Colors.red.shade400),
                                        const SizedBox(width: 4),
                                        Text('${p['likes_count'] ?? 0} Likes'),
                                        const SizedBox(width: 16),
                                        const Icon(Icons.mode_comment_outlined, size: 16, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text('${p['comments_count'] ?? 0} Comments'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Tab 4: Ad Leads ────────────────────────────────────────────────────────

  Widget _buildLeadsTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Captured Leads from Facebook & Instagram Ads',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: _leads.isEmpty
                ? const Center(child: Text('No ad leads recorded yet.'))
                : ListView.builder(
                    itemCount: _leads.length,
                    itemBuilder: (ctx, i) {
                      final lead = _leads[i];
                      final isConverted = lead['status'] == 'CONVERTED';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: lead['platform'] == 'INSTAGRAM'
                                ? Colors.purple.shade50
                                : Colors.blue.shade50,
                            child: Icon(
                              lead['platform'] == 'INSTAGRAM' ? Icons.camera_alt : Icons.facebook,
                              color: lead['platform'] == 'INSTAGRAM' ? Colors.purple : Colors.blue,
                            ),
                          ),
                          title: Text(lead['customer_name'] ?? 'Lead', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              'Phone: ${lead['customer_phone'] ?? 'N/A'} • Campaign: ${lead['ad_campaign']}\nNote: ${lead['inquiry_notes'] ?? ''}'),
                          isThreeLine: true,
                          trailing: isConverted
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('Converted (#${lead['converted_order_number'] ?? 'Order'})',
                                      style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                                )
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
                                  onPressed: () => _convertLeadToOrder(lead['id']),
                                  child: const Text('Convert to Order', style: TextStyle(color: Colors.white)),
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Tab 5: API Settings ────────────────────────────────────────────────────

  Widget _buildApiSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          child: PanelCard(
            title: 'Local Meta Graph API & Credentials',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Provide your Meta Graph API User or Page Access Token from developers.facebook.com to manage Facebook Pages and linked Instagram accounts directly.',
                  style: TextStyle(color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 20),
                const Text('Page Access Token / User Token', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: _tokenController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'EAAB...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Facebook Page Name', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _pageNameController,
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Instagram Username', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _igUserController,
                            decoration: const InputDecoration(
                              prefixText: '@',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable Meta AI Auto-Reply on DMs',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Automatically reply to new Instagram & FB messages using Llama 3 AI model.'),
                  value: _autoReplyEnabled,
                  onChanged: (val) => setState(() => _autoReplyEnabled = val),
                ),
                const SizedBox(height: 24),
                if (_verifyResultMsg != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _verifySuccess == true ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _verifySuccess == true ? Colors.green.shade300 : Colors.red.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _verifySuccess == true ? Icons.check_circle : Icons.error,
                          color: _verifySuccess == true ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _verifyResultMsg!,
                            style: TextStyle(
                              color: _verifySuccess == true ? Colors.green.shade900 : Colors.red.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF182C4F),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      onPressed: _saveSettings,
                      child: const Text('Save Credentials', style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                      onPressed: _testingConnection ? null : _verifyConnection,
                      icon: _testingConnection
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded),
                      label: Text(_testingConnection ? 'Testing...' : 'Test Connection'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
