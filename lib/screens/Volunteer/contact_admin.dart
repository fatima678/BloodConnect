import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String baseUrl =
      'https://manliness-smugness-qualm.ngrok-free.dev/api';

  static const String tokenKey = 'auth_token';

  static const String volunteerSendMessage = '$baseUrl/volunteer/contact-admin';
  static const String volunteerMessages =
      '$baseUrl/volunteer/contact-admin/messages';

  static const String adminContacts = '$baseUrl/admin/volunteer-contacts';
}

class ContactAdmin extends StatefulWidget {
  const ContactAdmin({super.key});

  @override
  State<ContactAdmin> createState() => _ContactAdminState();
}

class _ContactAdminState extends State<ContactAdmin> {
  int selectedIndex = 0;

  final pages = const [
    VolunteerMessagesScreen(),
    AdminVolunteerContactsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        scaffoldBackgroundColor: AppColors.softWhite,
        primaryColor: AppColors.maroon,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.maroon,
          primary: AppColors.maroon,
          surface: AppColors.softWhite,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.maroon,
          foregroundColor: AppColors.white,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.maroon,
            foregroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.maroon, width: 1.4),
          ),
        ),
      ),
      child: Scaffold(
        body: pages[selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: selectedIndex,
          selectedItemColor: AppColors.maroon,
          unselectedItemColor: AppColors.muted,
          backgroundColor: AppColors.white,
          onTap: (index) {
            setState(() {
              selectedIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.mail_outline),
              activeIcon: Icon(Icons.mail),
              label: 'Volunteer',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_outlined),
              activeIcon: Icon(Icons.admin_panel_settings),
              label: 'Admin',
            ),
          ],
        ),
      ),
    );
  }
}

class AppColors {
  static const Color maroon = Color(0xFF7B1020);
  static const Color maroonDark = Color(0xFF5C0B17);
  static const Color maroonLight = Color(0xFFA32238);
  static const Color white = Colors.white;
  static const Color softWhite = Color(0xFFFAF7F8);
  static const Color border = Color(0xFFEAD8DC);
  static const Color text = Color(0xFF2D1F22);
  static const Color muted = Color(0xFF7B6B70);
  static const Color success = Color(0xFF198754);
  static const Color danger = Color(0xFFDC3545);
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class VolunteerContactMessage {
  final String contactId;
  final String volunteerUid;
  final String volunteerName;
  final String volunteerEmail;
  final String volunteerPhone;
  final String subject;
  final String message;
  final String issueType;
  final String status;
  final String adminReply;
  final String adminRepliedAt;
  final bool isReadByAdmin;
  final bool isReadByVolunteer;
  final String createdAt;
  final String updatedAt;

  VolunteerContactMessage({
    required this.contactId,
    required this.volunteerUid,
    required this.volunteerName,
    required this.volunteerEmail,
    required this.volunteerPhone,
    required this.subject,
    required this.message,
    required this.issueType,
    required this.status,
    required this.adminReply,
    required this.adminRepliedAt,
    required this.isReadByAdmin,
    required this.isReadByVolunteer,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VolunteerContactMessage.fromJson(Map<String, dynamic> json) {
    return VolunteerContactMessage(
      contactId: _string(json['contact_id']),
      volunteerUid: _string(json['volunteer_uid']),
      volunteerName: _string(json['volunteer_name'], fallback: 'Volunteer'),
      volunteerEmail: _string(json['volunteer_email']),
      volunteerPhone: _string(json['volunteer_phone']),
      subject: _string(json['subject']),
      message: _string(json['message']),
      issueType: _string(json['issue_type']),
      status: _string(json['status'], fallback: 'open'),
      adminReply: _string(json['admin_reply']),
      adminRepliedAt: _string(json['admin_replied_at']),
      isReadByAdmin: _bool(json['is_read_by_admin']),
      isReadByVolunteer: _bool(json['is_read_by_volunteer']),
      createdAt: _string(json['created_at']),
      updatedAt: _string(json['updated_at']),
    );
  }

  static String _string(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  static bool _bool(dynamic value) {
    if (value == true) return true;
    if (value == false) return false;
    if (value is int) return value == 1;
    if (value is String) {
      final v = value.toLowerCase().trim();
      return v == 'true' || v == '1' || v == 'yes';
    }
    return false;
  }
}

class VolunteerContactApi {
  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();

    final keys = [
      ApiConfig.tokenKey,
      'token',
      'firebase_token',
      'id_token',
      'idToken',
      'admin_token',
      'volunteer_token',
      'access_token',
    ];

    for (final key in keys) {
      final token = prefs.getString(key);
      if (token != null && token.trim().isNotEmpty) {
        return token.trim();
      }
    }

    throw ApiException('Login token not found. Please login again.');
  }

  Future<Map<String, String>> _headers() async {
    final token = await _getToken();

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'ngrok-skip-browser-warning': 'true',
    };
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    Map<String, dynamic> decoded = {};

    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        decoded = body;
      } else if (body is Map) {
        decoded = Map<String, dynamic>.from(body);
      }
    } catch (_) {
      throw ApiException(
        'Invalid server response.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        decoded['message']?.toString() ?? 'Request failed.',
        statusCode: response.statusCode,
      );
    }

    if (decoded['success'] == false) {
      throw ApiException(
        decoded['message']?.toString() ?? 'Request failed.',
        statusCode: response.statusCode,
      );
    }

    return decoded;
  }

  List<VolunteerContactMessage> _messagesFromResponse(
    Map<String, dynamic> decoded,
  ) {
    final rawData = decoded['data'];

    if (rawData is List) {
      return rawData
          .whereType<Map>()
          .map(
            (item) => VolunteerContactMessage.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    }

    return [];
  }

  VolunteerContactMessage _messageFromResponse(
    Map<String, dynamic> decoded,
  ) {
    final rawData = decoded['data'];

    if (rawData is Map) {
      return VolunteerContactMessage.fromJson(
        Map<String, dynamic>.from(rawData),
      );
    }

    throw ApiException('Message data not found.');
  }

  Future<List<VolunteerContactMessage>> getVolunteerMessages() async {
    final response = await http.get(
      Uri.parse(ApiConfig.volunteerMessages),
      headers: await _headers(),
    );

    return _messagesFromResponse(_decodeResponse(response));
  }

  Future<VolunteerContactMessage> getVolunteerMessageDetail(
    String contactId,
  ) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.volunteerMessages}/$contactId'),
      headers: await _headers(),
    );

    return _messageFromResponse(_decodeResponse(response));
  }

  Future<VolunteerContactMessage> sendMessageToAdmin({
    required String subject,
    required String message,
    String? issueType,
    String? phone,
  }) async {
    final body = <String, dynamic>{
      'subject': subject.trim(),
      'message': message.trim(),
    };

    if (issueType != null && issueType.trim().isNotEmpty) {
      body['issue_type'] = issueType.trim();
    }

    if (phone != null && phone.trim().isNotEmpty) {
      body['phone'] = phone.trim();
    }

    final response = await http.post(
      Uri.parse(ApiConfig.volunteerSendMessage),
      headers: await _headers(),
      body: jsonEncode(body),
    );

    return _messageFromResponse(_decodeResponse(response));
  }

  Future<List<VolunteerContactMessage>> getAdminContacts() async {
    final response = await http.get(
      Uri.parse(ApiConfig.adminContacts),
      headers: await _headers(),
    );

    return _messagesFromResponse(_decodeResponse(response));
  }

  Future<VolunteerContactMessage> getAdminContactDetail(
    String contactId,
  ) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.adminContacts}/$contactId'),
      headers: await _headers(),
    );

    return _messageFromResponse(_decodeResponse(response));
  }

  Future<void> markAdminContactAsRead(String contactId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.adminContacts}/$contactId/mark-read'),
      headers: await _headers(),
    );

    _decodeResponse(response);
  }

  Future<void> replyToVolunteer({
    required String contactId,
    required String reply,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.adminContacts}/$contactId/reply'),
      headers: await _headers(),
      body: jsonEncode({
        'reply': reply.trim(),
        'admin_reply': reply.trim(),
        'message': reply.trim(),
      }),
    );

    _decodeResponse(response);
  }
}

class VolunteerMessagesScreen extends StatefulWidget {
  const VolunteerMessagesScreen({super.key});

  @override
  State<VolunteerMessagesScreen> createState() =>
      _VolunteerMessagesScreenState();
}

class _VolunteerMessagesScreenState extends State<VolunteerMessagesScreen> {
  final VolunteerContactApi api = VolunteerContactApi();

  bool loading = true;
  String? error;
  List<VolunteerContactMessage> messages = [];

  @override
  void initState() {
    super.initState();
    fetchMessages();
  }

  Future<void> fetchMessages() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await api.getVolunteerMessages();

      if (!mounted) return;

      setState(() {
        messages = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> openSendScreen() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const SendVolunteerMessageScreen(),
      ),
    );

    if (created == true) {
      fetchMessages();
    }
  }

  Future<void> openDetail(VolunteerContactMessage item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VolunteerMessageDetailScreen(
          contactId: item.contactId,
          isAdminView: false,
        ),
      ),
    );

    fetchMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        title: const Text('My Admin Messages'),
        actions: [
          IconButton(
            onPressed: fetchMessages,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.maroon,
        foregroundColor: AppColors.white,
        onPressed: openSendScreen,
        icon: const Icon(Icons.add),
        label: const Text('Contact Admin'),
      ),
      body: RefreshIndicator(
        onRefresh: fetchMessages,
        color: AppColors.maroon,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.maroon),
      );
    }

    if (error != null) {
      return ErrorState(
        message: error!,
        onRetry: fetchMessages,
      );
    }

    if (messages.isEmpty) {
      return EmptyState(
        title: 'No messages found',
        subtitle: 'Tap Contact Admin to send your first message.',
        buttonText: 'Contact Admin',
        onPressed: openSendScreen,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final item = messages[index];

        return ContactCard(
          item: item,
          isAdminView: false,
          onTap: () => openDetail(item),
        );
      },
    );
  }
}

class SendVolunteerMessageScreen extends StatefulWidget {
  const SendVolunteerMessageScreen({super.key});

  @override
  State<SendVolunteerMessageScreen> createState() =>
      _SendVolunteerMessageScreenState();
}

class _SendVolunteerMessageScreenState
    extends State<SendVolunteerMessageScreen> {
  final VolunteerContactApi api = VolunteerContactApi();

  final formKey = GlobalKey<FormState>();
  final subjectController = TextEditingController();
  final messageController = TextEditingController();
  final issueTypeController = TextEditingController();
  final phoneController = TextEditingController();

  bool submitting = false;

  @override
  void dispose() {
    subjectController.dispose();
    messageController.dispose();
    issueTypeController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      submitting = true;
    });

    try {
      await api.sendMessageToAdmin(
        subject: subjectController.text,
        message: messageController.text,
        issueType: issueTypeController.text,
        phone: phoneController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message sent to admin successfully.'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        title: const Text('Contact Admin'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: CardContainer(
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Send Message to Admin',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Write your issue or request. Admin will reply from dashboard.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    hintText: 'Example: Event issue',
                    prefixIcon: Icon(Icons.subject),
                  ),
                  maxLength: 150,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Subject is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: issueTypeController,
                  decoration: const InputDecoration(
                    labelText: 'Issue Type Optional',
                    hintText: 'Example: Event, Profile, Notification',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Optional',
                    hintText: '03000000000',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: messageController,
                  maxLines: 6,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Write your message here...',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.message_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Message is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: submitting ? null : submit,
                    icon: submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(submitting ? 'Sending...' : 'Send Message'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminVolunteerContactsScreen extends StatefulWidget {
  const AdminVolunteerContactsScreen({super.key});

  @override
  State<AdminVolunteerContactsScreen> createState() =>
      _AdminVolunteerContactsScreenState();
}

class _AdminVolunteerContactsScreenState
    extends State<AdminVolunteerContactsScreen> {
  final VolunteerContactApi api = VolunteerContactApi();

  bool loading = true;
  String? error;
  List<VolunteerContactMessage> contacts = [];

  int get unreadCount =>
      contacts.where((item) => item.isReadByAdmin == false).length;

  @override
  void initState() {
    super.initState();
    fetchContacts();
  }

  Future<void> fetchContacts() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await api.getAdminContacts();

      if (!mounted) return;

      setState(() {
        contacts = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> openDetail(VolunteerContactMessage item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VolunteerMessageDetailScreen(
          contactId: item.contactId,
          isAdminView: true,
        ),
      ),
    );

    fetchContacts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        title: const Text('Volunteer Contacts'),
        actions: [
          IconButton(
            onPressed: fetchContacts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: fetchContacts,
        color: AppColors.maroon,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.maroon),
      );
    }

    if (error != null) {
      return ErrorState(
        message: error!,
        onRetry: fetchContacts,
      );
    }

    if (contacts.isEmpty) {
      return const EmptyState(
        title: 'No volunteer contacts',
        subtitle: 'Volunteer messages will appear here.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        SummaryBox(
          total: contacts.length,
          unread: unreadCount,
        ),
        const SizedBox(height: 12),
        ...contacts.map(
          (item) => ContactCard(
            item: item,
            isAdminView: true,
            onTap: () => openDetail(item),
          ),
        ),
      ],
    );
  }
}

class VolunteerMessageDetailScreen extends StatefulWidget {
  final String contactId;
  final bool isAdminView;

  const VolunteerMessageDetailScreen({
    super.key,
    required this.contactId,
    required this.isAdminView,
  });

  @override
  State<VolunteerMessageDetailScreen> createState() =>
      _VolunteerMessageDetailScreenState();
}

class _VolunteerMessageDetailScreenState
    extends State<VolunteerMessageDetailScreen> {
  final VolunteerContactApi api = VolunteerContactApi();
  final replyController = TextEditingController();

  bool loading = true;
  bool actionLoading = false;
  String? error;
  VolunteerContactMessage? message;

  @override
  void initState() {
    super.initState();
    fetchDetail();
  }

  @override
  void dispose() {
    replyController.dispose();
    super.dispose();
  }

  Future<void> fetchDetail() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = widget.isAdminView
          ? await api.getAdminContactDetail(widget.contactId)
          : await api.getVolunteerMessageDetail(widget.contactId);

      if (!mounted) return;

      setState(() {
        message = result;
        replyController.clear();
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> markRead() async {
    setState(() {
      actionLoading = true;
    });

    try {
      await api.markAdminContactAsRead(widget.contactId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marked as read.'),
          backgroundColor: AppColors.success,
        ),
      );

      await fetchDetail();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          actionLoading = false;
        });
      }
    }
  }

  Future<void> sendReply() async {
    final reply = replyController.text.trim();

    if (reply.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply message is required.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() {
      actionLoading = true;
    });

    try {
      await api.replyToVolunteer(
        contactId: widget.contactId,
        reply: reply,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply sent successfully.'),
          backgroundColor: AppColors.success,
        ),
      );

      await fetchDetail();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          actionLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isAdminView ? 'Contact Detail' : 'Message Detail';

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        title: Text(title),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.maroon),
      );
    }

    if (error != null) {
      return ErrorState(
        message: error!,
        onRetry: fetchDetail,
      );
    }

    final item = message;

    if (item == null) {
      return const EmptyState(
        title: 'Message not found',
        subtitle: 'No detail available.',
      );
    }

    return RefreshIndicator(
      onRefresh: fetchDetail,
      color: AppColors.maroon,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusBadge(
                      text: item.status,
                      color: item.status.toLowerCase() == 'open'
                          ? AppColors.maroon
                          : AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    if (widget.isAdminView)
                      StatusBadge(
                        text: item.isReadByAdmin ? 'Read' : 'Unread',
                        color: item.isReadByAdmin
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  item.subject.isEmpty ? 'No Subject' : item.subject,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formatDate(item.createdAt),
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                if (widget.isAdminView) ...[
                  InfoRow(label: 'Volunteer', value: item.volunteerName),
                  InfoRow(label: 'Email', value: item.volunteerEmail),
                  InfoRow(label: 'Phone', value: item.volunteerPhone),
                  InfoRow(label: 'Issue Type', value: item.issueType),
                  const Divider(height: 28),
                ],
                const Text(
                  'Volunteer Message',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.message.isEmpty ? 'No message found.' : item.message,
                  style: const TextStyle(
                    color: AppColors.text,
                    height: 1.5,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin Reply',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                if (item.adminReply.isEmpty)
                  const Text(
                    'No reply yet.',
                    style: TextStyle(color: AppColors.muted),
                  )
                else ...[
                  Text(
                    item.adminReply,
                    style: const TextStyle(
                      color: AppColors.text,
                      height: 1.5,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatDate(item.adminRepliedAt),
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
          if (widget.isAdminView) ...[
            const SizedBox(height: 14),
            CardContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Admin Actions',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!item.isReadByAdmin)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: actionLoading ? null : markRead,
                        icon: const Icon(Icons.done_all),
                        label: const Text('Mark as Read'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.maroon,
                          side: const BorderSide(color: AppColors.maroon),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  if (!item.isReadByAdmin) const SizedBox(height: 12),
                  TextField(
                    controller: replyController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Write Reply',
                      hintText: 'Type admin reply here...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: actionLoading ? null : sendReply,
                      icon: actionLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : const Icon(Icons.reply),
                      label: Text(
                        actionLoading ? 'Please wait...' : 'Send Reply',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ContactCard extends StatelessWidget {
  final VolunteerContactMessage item;
  final bool isAdminView;
  final VoidCallback onTap;

  const ContactCard({
    super.key,
    required this.item,
    required this.isAdminView,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasReply = item.adminReply.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.maroon.withOpacity(0.1),
              foregroundColor: AppColors.maroon,
              child: Icon(
                hasReply ? Icons.mark_email_read : Icons.mail_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isAdminView) ...[
                    Text(
                      item.volunteerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    item.subject.isEmpty ? 'No Subject' : item.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.message.isEmpty ? 'No message found.' : item.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusBadge(
                        text: hasReply ? 'Replied' : 'Pending',
                        color: hasReply ? AppColors.success : AppColors.maroon,
                      ),
                      if (isAdminView)
                        StatusBadge(
                          text: item.isReadByAdmin ? 'Read' : 'Unread',
                          color: item.isReadByAdmin
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      StatusBadge(
                        text: formatDate(item.createdAt),
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class SummaryBox extends StatelessWidget {
  final int total;
  final int unread;

  const SummaryBox({
    super.key,
    required this.total,
    required this.unread,
  });

  @override
  Widget build(BuildContext context) {
    return CardContainer(
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              title: 'Total',
              value: total.toString(),
              icon: Icons.inbox,
            ),
          ),
          Container(
            height: 44,
            width: 1,
            color: AppColors.border,
          ),
          Expanded(
            child: _SummaryItem(
              title: 'Unread',
              value: unread.toString(),
              icon: Icons.mark_email_unread,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryItem({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.maroon.withOpacity(0.1),
          foregroundColor: AppColors.maroon,
          child: Icon(icon),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              title,
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ],
    );
  }
}

class CardContainer extends StatelessWidget {
  final Widget child;

  const CardContainer({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  const StatusBadge({
    super.key,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final value = text.trim().isEmpty ? 'N/A' : text.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onPressed;

  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 90),
        Icon(
          Icons.inbox_outlined,
          size: 76,
          color: AppColors.maroon.withOpacity(0.35),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
        if (buttonText != null && onPressed != null) ...[
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: onPressed,
            child: Text(buttonText!),
          ),
        ],
      ],
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 90),
        const Icon(
          Icons.error_outline,
          size: 76,
          color: AppColors.danger,
        ),
        const SizedBox(height: 18),
        const Text(
          'Something went wrong',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.text,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 22),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}

String formatDate(String value) {
  if (value.trim().isEmpty) return 'N/A';

  try {
    final date = DateTime.parse(value).toLocal();

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day-$month-$year $hour:$minute';
  } catch (_) {
    return value;
  }
}