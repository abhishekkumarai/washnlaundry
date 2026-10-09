import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool _syncingMeta = false;
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

  // WhatsApp Tab state
  String? _selectedWaConvId;
  String _selectedWaSender = '';
  String _selectedWaPhone = '';
  List<dynamic> _activeWaMessages = [];
  bool _waMessagesLoading = false;
  final TextEditingController _waMsgInputController = TextEditingController();
  final ScrollController _waChatScrollController = ScrollController();

  // Settings controllers
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _pageNameController = TextEditingController();
  final TextEditingController _igUserController = TextEditingController();
  final TextEditingController _waPhoneIdController = TextEditingController();
  final TextEditingController _waWabaIdController = TextEditingController();
  final TextEditingController _waPhoneNumberController = TextEditingController();
  bool _autoReplyEnabled = true;
  bool _testingConnection = false;
  String? _verifyResultMsg;
  bool? _verifySuccess;

  // New Post Dialog controllers
  final TextEditingController _postContentController = TextEditingController();
  final TextEditingController _postImageController = TextEditingController();
  String _postPlatform = 'BOTH';

  // New WhatsApp Contact Dialog controllers
  final TextEditingController _newWaNameController = TextEditingController();
  final TextEditingController _newWaPhoneController = TextEditingController();
  final TextEditingController _newWaMsgController = TextEditingController();

  // Neonize Personal WhatsApp state
  Map<String, dynamic> _neonizeStatus = {};
  bool _neonizeLoading = false;
  Timer? _neonizePollTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _neonizePollTimer?.cancel();
    _tabController.dispose();
    _msgInputController.dispose();
    _chatScrollController.dispose();
    _waMsgInputController.dispose();
    _waChatScrollController.dispose();
    _tokenController.dispose();
    _pageNameController.dispose();
    _igUserController.dispose();
    _waPhoneIdController.dispose();
    _waWabaIdController.dispose();
    _waPhoneNumberController.dispose();
    _postContentController.dispose();
    _postImageController.dispose();
    _newWaNameController.dispose();
    _newWaPhoneController.dispose();
    _newWaMsgController.dispose();
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
      final resNeonize = await ApiService.fetchNeonizeStatus();

      setState(() {
        _settings = resSettings;
        _analytics = resAnalytics;
        _posts = resPosts;
        _leads = resLeads;
        _conversations = resConvs;
        _neonizeStatus = resNeonize;

        _tokenController.text = (_settings['page_access_token'] != null && (_settings['page_access_token'] as String).isNotEmpty)
            ? _settings['page_access_token']
            : (_settings['user_access_token'] ?? '');
        _pageNameController.text = _settings['facebook_page_name'] ?? 'Washnlaundry';
        _igUserController.text = _settings['instagram_username'] ?? 'washnlaundrydotcom';
        _waPhoneIdController.text = _settings['whatsapp_phone_number_id'] ?? '';
        _waWabaIdController.text = _settings['whatsapp_business_account_id'] ?? '';
        _waPhoneNumberController.text = _settings['whatsapp_phone_number'] ?? '';
        _autoReplyEnabled = _settings['auto_reply_enabled'] ?? true;

        if (_conversations.isNotEmpty && _selectedConvId == null) {
          _selectConversation(_conversations.first['conversation_id'],
              _conversations.first['platform'], _conversations.first['sender_name']);
        }

        // Initialize active WhatsApp conversation if available
        final waConvs = _conversations.where((c) => c['platform'] == 'WHATSAPP').toList();
        if (waConvs.isNotEmpty && _selectedWaConvId == null) {
          _selectWhatsAppConversation(
            waConvs.first['conversation_id'],
            waConvs.first['sender_name'] ?? 'WhatsApp Contact',
          );
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

  Future<void> _startNeonizePairing({bool openDialog = true}) async {
    setState(() => _neonizeLoading = true);
    try {
      final res = await ApiService.connectNeonize();
      if (mounted) {
        setState(() {
          _neonizeStatus = res;
          _neonizeLoading = false;
        });
        if (openDialog) {
          _showNeonizeQrDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _neonizeLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initiate pairing: $e')),
        );
      }
    }
  }

  Future<void> _disconnectNeonize() async {
    setState(() => _neonizeLoading = true);
    try {
      final res = await ApiService.disconnectNeonize();
      if (mounted) {
        setState(() {
          _neonizeStatus = res;
          _neonizeLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Personal WhatsApp unlinked successfully.'),
            backgroundColor: Color(0xFF182C4F),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _neonizeLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to disconnect: $e')),
        );
      }
    }
  }

  void _startNeonizePolling() {
    _neonizePollTimer?.cancel();
    _neonizePollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final res = await ApiService.fetchNeonizeStatus();
      if (mounted) {
        setState(() => _neonizeStatus = res);
      }
    });
  }

  void _stopNeonizePolling() {
    _neonizePollTimer?.cancel();
    _neonizePollTimer = null;
  }

  void _showNeonizeQrDialog() {
    _startNeonizePolling();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isConnected = _neonizeStatus['connected'] == true;
          final qrCodeData = _neonizeStatus['qr_code'] as String?;
          final phone = _neonizeStatus['phone']?.toString() ?? '';

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code_2, color: Color(0xFF25D366), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Link Personal WhatsApp',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Neonize Multi-Device Protocol (No Business API needed)',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isConnected) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF16A34A), size: 54),
                            const SizedBox(height: 12),
                            const Text(
                              'Personal WhatsApp Linked!',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF15803D)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              phone.isNotEmpty ? 'Active Number: +$phone' : 'Status: Ready for CRM messaging',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF166534)),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade300),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _disconnectNeonize();
                              },
                              icon: const Icon(Icons.link_off, size: 16),
                              label: const Text('Unlink This Number'),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // QR Code Container
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: qrCodeData != null && qrCodeData.contains(',')
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  base64Decode(qrCodeData.split(',').last),
                                  width: 220,
                                  height: 220,
                                  fit: BoxFit.contain,
                                ),
                              )
                            : SizedBox(
                                width: 220,
                                height: 220,
                                child: Center(
                                  child: _neonizeLoading
                                      ? const CircularProgressIndicator()
                                      : const Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.qr_code, size: 48, color: Colors.grey),
                                            SizedBox(height: 8),
                                            Text('Initializing pairing...',
                                                style: TextStyle(color: Colors.grey, fontSize: 13)),
                                          ],
                                        ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      // Instruction steps
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('How to link your personal number:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            SizedBox(height: 6),
                            Text('1. Open WhatsApp on your personal phone.'),
                            Text('2. Tap Settings (iOS) or ⋮ Menu (Android) > Linked Devices.'),
                            Text('3. Tap "Link a Device" and scan the QR code above.'),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              if (!isConnected)
                TextButton.icon(
                  onPressed: () async {
                    await _startNeonizePairing(openDialog: false);
                    setDlgState(() {});
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh QR'),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF182C4F),
                ),
                onPressed: () {
                  _stopNeonizePolling();
                  Navigator.pop(ctx);
                },
                child: const Text('Done', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    ).then((_) => _stopNeonizePolling());
  }

  Future<void> _syncFromMeta() async {
    setState(() => _syncingMeta = true);
    try {
      final res = await ApiService.syncMetaSocial();
      if (mounted) {
        final count = res['synced_posts_count'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['success'] == true
                ? 'Synced $count post(s) and followers from Meta successfully!'
                : (res['message'] ?? 'Sync failed')),
            backgroundColor: res['success'] == true ? const Color(0xFF0F766E) : Colors.red,
          ),
        );
      }
      await _loadAllData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _syncingMeta = false);
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

  Future<void> _sendMessage({bool useAi = false, bool isCustomerSimulation = false}) async {
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
        senderName: isCustomerSimulation ? _selectedConvSender : 'Staff Support',
        senderType: isCustomerSimulation ? 'USER' : 'STAFF',
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

  Future<void> _selectWhatsAppConversation(String convId, String sender) async {
    setState(() {
      _selectedWaConvId = convId;
      _selectedWaSender = sender;
      _selectedWaPhone = convId.replaceAll('wa_', '');
      _waMessagesLoading = true;
    });

    try {
      final msgs = await ApiService.fetchMetaMessages(convId);
      setState(() {
        _activeWaMessages = msgs;
        _waMessagesLoading = false;
      });
      _scrollToWaBottom();
    } catch (e) {
      setState(() {
        _waMessagesLoading = false;
      });
    }
  }

  void _scrollToWaBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_waChatScrollController.hasClients) {
        _waChatScrollController.animateTo(
          _waChatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendWhatsAppReply() async {
    final text = _waMsgInputController.text.trim();
    if (text.isEmpty) return;
    final phone = _selectedWaPhone.isNotEmpty ? _selectedWaPhone : (_selectedWaConvId?.replaceAll('wa_', '') ?? '');
    if (phone.isEmpty) return;

    _waMsgInputController.clear();
    setState(() => _waMessagesLoading = true);

    try {
      final res = await ApiService.sendWhatsAppMessage(
        phone: phone,
        text: text,
        recipientName: _selectedWaSender,
      );
      final cid = res['conversation_id'] ?? _selectedWaConvId ?? 'wa_$phone';
      final updatedMsgs = await ApiService.fetchMetaMessages(cid);
      final updatedConvs = await ApiService.fetchMetaConversations();
      setState(() {
        _selectedWaConvId = cid;
        _activeWaMessages = updatedMsgs;
        _conversations = updatedConvs;
        _waMessagesLoading = false;
      });
      _scrollToWaBottom();
      if (res['simulated'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message saved in simulated mode (Phone Number ID pending in API Settings).'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _waMessagesLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send WhatsApp message: $e')),
        );
      }
    }
  }

  void _showNewWhatsAppContactDialog() {
    _newWaNameController.clear();
    _newWaPhoneController.clear();
    _newWaMsgController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline, color: Color(0xFF25D366)),
            SizedBox(width: 8),
            Text('New WhatsApp Chat'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Recipient Name', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _newWaNameController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Rahul Sharma',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              const Text('WhatsApp Mobile Number (10 digits only, no ISD code)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _newWaPhoneController,
                decoration: const InputDecoration(
                  hintText: '9876543210',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Initial Message', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _newWaMsgController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Hi, thank you for choosing WashNLaundry! How can we assist you today?',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            onPressed: () async {
              final phone = _newWaPhoneController.text.trim();
              final text = _newWaMsgController.text.trim();
              final name = _newWaNameController.text.trim().isNotEmpty
                  ? _newWaNameController.text.trim()
                  : 'Customer ($phone)';
              if (phone.isEmpty || text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide both phone number and message.')),
                );
                return;
              }
              if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mobile number must be exactly 10 digits starting with 6-9 (no ISD / country code or leading 0).'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                final res = await ApiService.sendWhatsAppMessage(
                  phone: phone,
                  text: text,
                  recipientName: name,
                );
                final cid = res['conversation_id'] ?? 'wa_$phone';
                await _loadAllData();
                _selectWhatsAppConversation(cid, name);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['simulated'] == true
                          ? 'Message queued (Simulated dispatch - live Phone ID can be added in Settings).'
                          : 'WhatsApp message sent successfully!'),
                      backgroundColor: const Color(0xFF25D366),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to initiate WhatsApp chat: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            label: const Text('Send Message', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    try {
      await ApiService.updateMetaSettings({
        'page_access_token': _tokenController.text.trim(),
        'facebook_page_name': _pageNameController.text.trim(),
        'instagram_username': _igUserController.text.trim(),
        'whatsapp_phone_number_id': _waPhoneIdController.text.trim(),
        'whatsapp_business_account_id': _waWabaIdController.text.trim(),
        'whatsapp_phone_number': _waPhoneNumberController.text.trim(),
        'auto_reply_enabled': _autoReplyEnabled,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meta & WhatsApp credentials saved successfully.')),
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
        body: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 768;

            return Column(
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
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: const Color(0xFF182C4F),
                    unselectedLabelColor: const Color(0xFF64748B),
                    indicatorColor: const Color(0xFF182C4F),
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(icon: Icon(Icons.analytics_outlined), text: 'Analytics'),
                      Tab(icon: Icon(Icons.forum_outlined), text: 'AI & DMs'),
                      Tab(icon: Icon(Icons.chat_bubble_outline), text: 'WhatsApp'),
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
                                _buildAnalyticsTab(narrow),
                                _buildChatAndDmsTab(narrow),
                                _buildWhatsAppTab(narrow),
                                _buildPostsTab(narrow),
                                _buildLeadsTab(narrow),
                                _buildApiSettingsTab(narrow),
                              ],
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Tab 1: Analytics ─────────────────────────────────────────────────────────

  Widget _buildAnalyticsTab(bool narrow) {
    final ov = _analytics['overview'] ?? {};
    final channels = (_analytics['channels'] as List?) ?? [];
    final isConnected = ov['is_connected'] == true;

    final statReach = _buildStatCard('Total Reach', '${ov['total_reach'] ?? 0}', Icons.remove_red_eye_outlined, Colors.blue);
    final statIg = _buildStatCard('Instagram Followers', '${ov['followers_instagram'] ?? 0}', Icons.camera_alt_outlined, Colors.purple);
    final statFb = _buildStatCard('Facebook Followers', '${ov['followers_facebook'] ?? 0}', Icons.facebook_outlined, Colors.indigo);
    final statLeads = _buildStatCard('Total Ad Leads', '${ov['total_leads'] ?? 0}', Icons.group_add_outlined, Colors.teal);

    final channelsPanel = PanelCard(
      title: 'Connected Meta Channels',
      child: Column(
        children: channels.map<Widget>((ch) {
          final hasPic = (ch['profile_picture_url'] != null && (ch['profile_picture_url'] as String).isNotEmpty);
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: ch['platform'] == 'Instagram'
                  ? Colors.purple.shade50
                  : Colors.blue.shade50,
              backgroundImage: hasPic ? NetworkImage(ch['profile_picture_url']) : null,
              child: !hasPic
                  ? Icon(
                      ch['platform'] == 'Instagram' ? Icons.camera_alt : Icons.facebook,
                      color: ch['platform'] == 'Instagram' ? Colors.purple : Colors.blue,
                    )
                  : null,
            ),
            title: Text(ch['platform'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              ch['media_count'] != null
                  ? '${ch['handle'] ?? ''} • ${ch['media_count']} Media / Reels'
                  : (ch['handle'] ?? ''),
            ),
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
    );

    final metricsPanel = PanelCard(
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
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(narrow ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (narrow) ...[
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected ? const Color(0xFF0F766E) : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isConnected ? 'Live Meta Graph API Connected' : 'Meta API Offline / Simulation',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isConnected ? const Color(0xFF0F766E) : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF182C4F),
                  side: const BorderSide(color: Color(0xFF182C4F)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: _syncingMeta ? null : _syncFromMeta,
                icon: _syncingMeta
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded, size: 18),
                label: Text(_syncingMeta ? 'Syncing...' : 'Sync Live from Meta'),
              ),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isConnected ? const Color(0xFF0F766E) : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isConnected ? 'Live Meta Graph API Connected' : 'Meta API Offline / Simulation',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isConnected ? const Color(0xFF0F766E) : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF182C4F),
                    side: const BorderSide(color: Color(0xFF182C4F)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: _syncingMeta ? null : _syncFromMeta,
                  icon: _syncingMeta
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded, size: 18),
                  label: Text(_syncingMeta ? 'Syncing...' : 'Sync Live from Meta'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (narrow) ...[
            Row(
              children: [
                Expanded(child: statReach),
                const SizedBox(width: 10),
                Expanded(child: statIg),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: statFb),
                const SizedBox(width: 10),
                Expanded(child: statLeads),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(child: statReach),
                const SizedBox(width: 16),
                Expanded(child: statIg),
                const SizedBox(width: 16),
                Expanded(child: statFb),
                const SizedBox(width: 16),
                Expanded(child: statLeads),
              ],
            ),
          ],
          const SizedBox(height: 20),
          if (narrow) ...[
            channelsPanel,
            const SizedBox(height: 16),
            metricsPanel,
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: channelsPanel),
                const SizedBox(width: 24),
                Expanded(flex: 2, child: metricsPanel),
              ],
            ),
          ],
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E0D8)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: AI & DMs ─────────────────────────────────────────────────────────

  Widget _buildChatAndDmsTab(bool narrow) {
    final threadList = Container(
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
    );

    final chatPane = Container(
      color: const Color(0xFFF8F7F5),
      child: Column(
        children: [
          // Active chat header
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.white,
            child: Row(
              children: [
                if (narrow) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _selectedConvId = null),
                  ),
                  const SizedBox(width: 8),
                ],
                CircleAvatar(
                  backgroundColor: _selectedConvPlatform == 'INSTAGRAM'
                      ? Colors.purple.shade100
                      : Colors.blue.shade100,
                  child: Text(_selectedConvSender.isNotEmpty ? _selectedConvSender[0] : 'C'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedConvSender,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'via $_selectedConvPlatform DM',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (!narrow) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.smart_toy, size: 16, color: Color(0xFF0369A1)),
                        SizedBox(width: 4),
                        Text('Meta AI Active', style: TextStyle(color: Color(0xFF0369A1), fontSize: 12)),
                      ],
                    ),
                  ),
                ],
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
                          'No messages in this conversation.\nType below to simulate an inquiry or reply.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: _chatScrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _activeMessages.length,
                        itemBuilder: (ctx, i) {
                          final msg = _activeMessages[i];
                          final isUser = msg['sender_type'] == 'USER';
                          final isAi = msg['sender_type'] == 'AI';
                          return Align(
                            alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              constraints: BoxConstraints(maxWidth: narrow ? 280 : 480),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? Colors.white
                                    : isAi
                                        ? const Color(0xFF182C4F)
                                        : const Color(0xFF0F766E),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)
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
                                      fontSize: 13,
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
            padding: EdgeInsets.all(narrow ? 10 : 16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgInputController,
                    decoration: InputDecoration(
                      hintText: narrow ? 'Type reply...' : 'Type customer inquiry or support reply...',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(useAi: false),
                  ),
                ),
                const SizedBox(width: 8),
                if (!narrow) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    onPressed: () => _sendMessage(useAi: true),
                    icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                    label: const Text('Meta AI Reply', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 6),
                ] else ...[
                  IconButton(
                    tooltip: 'Meta AI Reply',
                    icon: const Icon(Icons.auto_awesome, color: Color(0xFF0F766E)),
                    onPressed: () => _sendMessage(useAi: true),
                  ),
                ],
                IconButton(
                  tooltip: 'Send as Staff Support',
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF182C4F)),
                  onPressed: () => _sendMessage(useAi: false, isCustomerSimulation: false),
                ),
                IconButton(
                  tooltip: 'Simulate Customer Message',
                  icon: const Icon(Icons.person_add_alt_1_outlined, color: Color(0xFF64748B)),
                  onPressed: () => _sendMessage(useAi: false, isCustomerSimulation: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (narrow) {
      // In narrow view: master-detail navigation. If thread is selected, show chat with back arrow; else show threads
      return _selectedConvId != null ? chatPane : threadList;
    }

    return Row(
      children: [
        SizedBox(width: 320, child: threadList),
        const VerticalDivider(width: 1, color: Color(0xFFE4E0D8)),
        Expanded(child: chatPane),
      ],
    );
  }

  // ── Tab 3: WhatsApp from Meta ──────────────────────────────────────────────

  Widget _buildWhatsAppTab(bool narrow) {
    final waThreads = _conversations.where((c) => c['platform'] == 'WHATSAPP').toList();

    final contactsList = Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              border: Border(bottom: BorderSide(color: Color(0xFFDCFCE7))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WhatsApp Chats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('Meta Cloud API', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A))),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  icon: const Icon(Icons.person_add, size: 14),
                  label: const Text('New Contact'),
                  onPressed: _showNewWhatsAppContactDialog,
                ),
              ],
            ),
          ),
          // Personal WhatsApp (Neonize) status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _neonizeStatus['connected'] == true
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFFEF3C7).withValues(alpha: 0.4),
              border: Border(bottom: BorderSide(
                color: _neonizeStatus['connected'] == true
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFFDE68A),
              )),
            ),
            child: Row(
              children: [
                Icon(
                  _neonizeStatus['connected'] == true
                      ? Icons.phone_android_rounded
                      : Icons.qr_code_scanner_rounded,
                  size: 16,
                  color: _neonizeStatus['connected'] == true
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFD97706),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _neonizeStatus['connected'] == true
                            ? 'Personal WA: Linked (+${_neonizeStatus['phone'] ?? 'Active'})'
                            : 'Personal WA (No Biz API)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _neonizeStatus['connected'] == true
                              ? const Color(0xFF15803D)
                              : const Color(0xFF92400E),
                        ),
                      ),
                      Text(
                        _neonizeStatus['connected'] == true
                            ? 'Neonize Protocol Active'
                            : 'Scan QR to link personal number',
                        style: TextStyle(
                          fontSize: 10,
                          color: _neonizeStatus['connected'] == true
                              ? const Color(0xFF166534)
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    if (_neonizeStatus['connected'] == true) {
                      _showNeonizeQrDialog();
                    } else {
                      _startNeonizePairing(openDialog: true);
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: _neonizeStatus['connected'] == true
                          ? Colors.white
                          : const Color(0xFF0F766E),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _neonizeStatus['connected'] == true
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFF0F766E),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _neonizeStatus['connected'] == true
                              ? Icons.info_outline
                              : Icons.qr_code_2,
                          size: 12,
                          color: _neonizeStatus['connected'] == true
                              ? const Color(0xFF15803D)
                              : Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _neonizeStatus['connected'] == true ? 'Details' : 'Link QR',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _neonizeStatus['connected'] == true
                                ? const Color(0xFF15803D)
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: waThreads.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_in_talk_outlined, size: 40, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text(
                            'No WhatsApp chats yet',
                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Click "New Contact" above to start a chat with any phone number.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF25D366),
                              side: const BorderSide(color: Color(0xFF25D366)),
                            ),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Contact & Chat'),
                            onPressed: _showNewWhatsAppContactDialog,
                          )
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: waThreads.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final conv = waThreads[i];
                      final isSel = conv['conversation_id'] == _selectedWaConvId;
                      final phone = (conv['conversation_id'] as String).replaceAll('wa_', '');
                      return ListTile(
                        selected: isSel,
                        selectedTileColor: const Color(0xFFDCFCE7).withValues(alpha: 0.5),
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFDCFCE7),
                          child: Icon(Icons.chat, color: Color(0xFF16A34A), size: 18),
                        ),
                        title: Text(
                          conv['sender_name'] ?? 'WhatsApp Contact',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('+$phone', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(
                              conv['last_message'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        onTap: () => _selectWhatsAppConversation(
                          conv['conversation_id'],
                          conv['sender_name'] ?? 'WhatsApp Contact',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    final chatPane = Container(
      color: const Color(0xFFEFEAE2), // Classic WhatsApp wallpaper background tone
      child: Column(
        children: [
          // Chat header
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.white,
            child: Row(
              children: [
                if (narrow) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _selectedWaConvId = null),
                  ),
                  const SizedBox(width: 8),
                ],
                CircleAvatar(
                  backgroundColor: const Color(0xFFDCFCE7),
                  child: Text(
                    _selectedWaSender.isNotEmpty ? _selectedWaSender[0] : 'W',
                    style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedWaSender.isNotEmpty ? _selectedWaSender : 'Select Contact',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        _selectedWaPhone.isNotEmpty
                            ? '+${_selectedWaPhone.replaceAll('+', '')} • WhatsApp'
                            : 'Meta Cloud API',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'New Contact',
                  icon: const Icon(Icons.person_add_alt_1, size: 20, color: Color(0xFF25D366)),
                  onPressed: _showNewWhatsAppContactDialog,
                ),
              ],
            ),
          ),
          // Chat Messages View
          Expanded(
            child: _waMessagesLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF25D366)))
                : _activeWaMessages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.mark_chat_read_outlined, size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            const Text(
                              'No messages yet in this WhatsApp chat.',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Type an update or notice below to send.',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                              onPressed: _showNewWhatsAppContactDialog,
                              icon: const Icon(Icons.add, color: Colors.white, size: 16),
                              label: const Text('Start New Chat', style: TextStyle(color: Colors.white)),
                            )
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _waChatScrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _activeWaMessages.length,
                        itemBuilder: (ctx, i) {
                          final msg = _activeWaMessages[i];
                          final isUser = msg['sender_type'] == 'USER';
                          return Align(
                            alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              constraints: BoxConstraints(maxWidth: narrow ? 280 : 460),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isUser ? Colors.white : const Color(0xFFDCF8C6), // WhatsApp green
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(12),
                                  topRight: const Radius.circular(12),
                                  bottomLeft: Radius.circular(isUser ? 2 : 12),
                                  bottomRight: Radius.circular(isUser ? 12 : 2),
                                ),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 3, offset: const Offset(0, 1))
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: isUser ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        isUser
                                            ? (msg['sender_name'] ?? 'Customer')
                                            : 'WashNLaundry (Staff)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isUser ? Colors.grey.shade700 : const Color(0xFF0F5132),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    msg['text'] ?? '',
                                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          // WhatsApp Input Row
          Container(
            padding: EdgeInsets.all(narrow ? 10 : 16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _waMsgInputController,
                    decoration: InputDecoration(
                      hintText: _selectedWaPhone.isNotEmpty
                          ? 'Send to ${_selectedWaSender.isNotEmpty ? _selectedWaSender : _selectedWaPhone}...'
                          : 'Type message...',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      prefixIcon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 18),
                    ),
                    onSubmitted: (_) => _sendWhatsAppReply(),
                  ),
                ),
                const SizedBox(width: 8),
                if (!narrow) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onPressed: _sendWhatsAppReply,
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    label: const Text('Send WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ] else ...[
                  IconButton(
                    tooltip: 'Send',
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF25D366)),
                    onPressed: _sendWhatsAppReply,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (narrow) {
      return _selectedWaConvId != null ? chatPane : contactsList;
    }

    return Row(
      children: [
        SizedBox(width: 330, child: contactsList),
        const VerticalDivider(width: 1, color: Color(0xFFE4E0D8)),
        Expanded(child: chatPane),
      ],
    );
  }

  // ── Tab 4: Posts & Feed ────────────────────────────────────────────────────

  Widget _buildPostsTab(bool narrow) {
    final syncBtn = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF182C4F),
        side: const BorderSide(color: Color(0xFF182C4F)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      onPressed: _syncingMeta ? null : _syncFromMeta,
      icon: _syncingMeta
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync_rounded, size: 18),
      label: Text(_syncingMeta ? 'Syncing...' : 'Sync Live from Meta'),
    );

    final newPostBtn = ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF182C4F),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      onPressed: _showCreatePostDialog,
      icon: const Icon(Icons.add, color: Colors.white, size: 18),
      label: const Text('New Post', style: TextStyle(color: Colors.white)),
    );

    return Padding(
      padding: EdgeInsets.all(narrow ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (narrow) ...[
            const Text(
              'Scheduled & Published Social Posts',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: syncBtn),
                const SizedBox(width: 8),
                Expanded(child: newPostBtn),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Scheduled & Published Social Posts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    syncBtn,
                    const SizedBox(width: 12),
                    newPostBtn,
                  ],
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: _posts.isEmpty
                ? const Center(child: Text('No posts yet. Click "Sync Live from Meta" to fetch published posts.'))
                : ListView.builder(
                    itemCount: _posts.length,
                    itemBuilder: (ctx, i) {
                      final p = _posts[i];
                      final isIg = p['platform'] == 'INSTAGRAM';
                      final isVideo = p['media_type'] == 'VIDEO';
                      final permalink = p['permalink'] as String?;
                      final imgUrl = p['image_url'] as String?;

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
                                        if (isVideo)
                                          Container(
                                            margin: const EdgeInsets.only(right: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.play_arrow_rounded, size: 14, color: Colors.purple.shade900),
                                                Text(
                                                  'Reel',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.purple.shade900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
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
                                        if (permalink != null && permalink.isNotEmpty) ...[
                                          const SizedBox(width: 16),
                                          InkWell(
                                            onTap: () => launchUrl(Uri.parse(permalink)),
                                            child: Row(
                                              children: [
                                                Icon(Icons.open_in_new, size: 14, color: isIg ? Colors.purple : Colors.blue),
                                                const SizedBox(width: 4),
                                                Text(
                                                  isIg ? 'View on Instagram' : 'View on Facebook',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isIg ? Colors.purple : Colors.blue,
                                                    fontWeight: FontWeight.w600,
                                                    decoration: TextDecoration.underline,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (imgUrl != null && imgUrl.isNotEmpty) ...[
                                const SizedBox(width: 16),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    imgUrl,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                  ),
                                ),
                              ],
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

  // ── Tab 5: Ad Leads ────────────────────────────────────────────────────────

  Widget _buildLeadsTab(bool narrow) {
    return Padding(
      padding: EdgeInsets.all(narrow ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Captured Leads from Facebook & Instagram Ads',
              style: TextStyle(fontSize: narrow ? 16 : 18, fontWeight: FontWeight.bold)),
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
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: narrow
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: lead['platform'] == 'INSTAGRAM'
                                              ? Colors.purple.shade50
                                              : Colors.blue.shade50,
                                          child: Icon(
                                            lead['platform'] == 'INSTAGRAM' ? Icons.camera_alt : Icons.facebook,
                                            color: lead['platform'] == 'INSTAGRAM' ? Colors.purple : Colors.blue,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(lead['customer_name'] ?? 'Lead',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Phone: ${lead['customer_phone'] ?? 'N/A'} • Campaign: ${lead['ad_campaign']}\nNote: ${lead['inquiry_notes'] ?? ''}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                    ),
                                    const SizedBox(height: 10),
                                    isConverted
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text('Converted (#${lead['converted_order_number'] ?? 'Order'})',
                                                style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                                          )
                                        : SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
                                              onPressed: () => _convertLeadToOrder(lead['id']),
                                              child: const Text('Convert to Order', style: TextStyle(color: Colors.white)),
                                            ),
                                          ),
                                  ],
                                )
                              : ListTile(
                                  contentPadding: EdgeInsets.zero,
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Tab 6: API Settings ────────────────────────────────────────────────────

  Widget _buildApiSettingsTab(bool narrow) {
    final fbPageField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Facebook Page Name', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: _pageNameController,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ],
    );

    final igUserField = Column(
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
    );

    final waPhoneIdField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Phone Number ID', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _waPhoneIdController,
          decoration: const InputDecoration(
            hintText: 'e.g. 106540292837461',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );

    final waWabaIdField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('WhatsApp Business Account (WABA) ID', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _waWabaIdController,
          decoration: const InputDecoration(
            hintText: 'e.g. 109876543210987',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(narrow ? 16 : 24),
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
                if (narrow) ...[
                  fbPageField,
                  const SizedBox(height: 14),
                  igUserField,
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: fbPageField),
                      const SizedBox(width: 16),
                      Expanded(child: igUserField),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                const Text('WhatsApp Cloud API (Meta Business)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                if (narrow) ...[
                  waPhoneIdField,
                  const SizedBox(height: 14),
                  waWabaIdField,
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: waPhoneIdField),
                      const SizedBox(width: 16),
                      Expanded(child: waWabaIdField),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Registered WhatsApp Phone Number (10 digits)', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _waPhoneNumberController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'e.g. 9876543210 (10 digits only)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Personal WhatsApp (Neonize Protocol) Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF25D366),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Personal WhatsApp (Neonize Protocol)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('No Meta Business API required. Link your personal phone number via QR code.',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF166534))),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _neonizeStatus['connected'] == true
                                  ? const Color(0xFFDCFCE7)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _neonizeStatus['connected'] == true
                                    ? const Color(0xFF16A34A)
                                    : Colors.grey.shade400,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _neonizeStatus['connected'] == true
                                        ? const Color(0xFF16A34A)
                                        : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _neonizeStatus['connected'] == true
                                      ? 'Linked (+${_neonizeStatus['phone'] ?? 'Active'})'
                                      : 'Not Linked',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _neonizeStatus['connected'] == true
                                        ? const Color(0xFF15803D)
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            icon: const Icon(Icons.qr_code_2, size: 16),
                            label: Text(_neonizeStatus['connected'] == true ? 'View Link Details / QR' : 'Scan QR to Link Personal Device'),
                            onPressed: () {
                              if (_neonizeStatus['connected'] == true) {
                                _showNeonizeQrDialog();
                              } else {
                                _startNeonizePairing(openDialog: true);
                              }
                            },
                          ),
                          if (_neonizeStatus['connected'] == true) ...[
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade300),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              icon: const Icon(Icons.link_off, size: 14),
                              label: const Text('Unlink Number'),
                              onPressed: _disconnectNeonize,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
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
                if (_settings['facebook_page_id'] != null || _settings['instagram_account_id'] != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.verified_outlined, size: 16, color: Color(0xFF0F766E)),
                            SizedBox(width: 6),
                            Text('Connected Meta Asset Identifiers',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('• Facebook Page ID: ${_settings['facebook_page_id'] ?? '1283862214819700'} (${_settings['facebook_page_name'] ?? 'Washnlaundry'})',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                        const SizedBox(height: 4),
                        Text('• Instagram Account ID: ${_settings['instagram_account_id'] ?? '17841422947561202'} (@${_settings['instagram_username'] ?? 'washnlaundrydotcom'})',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                      ],
                    ),
                  ),
                ],
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF182C4F),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      onPressed: _saveSettings,
                      child: const Text('Save Credentials', style: TextStyle(color: Colors.white)),
                    ),
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
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F766E),
                        side: const BorderSide(color: Color(0xFF0F766E)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                      onPressed: _syncingMeta ? null : _syncFromMeta,
                      icon: _syncingMeta
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F766E)),
                            )
                          : const Icon(Icons.cloud_download_outlined, color: Color(0xFF0F766E)),
                      label: Text(_syncingMeta ? 'Syncing...' : 'Sync Live Data Now'),
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
