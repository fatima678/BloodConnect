import 'dart:async';

import 'package:flutter/material.dart';

import '../../sdk/volunteer/volunteer_contact_admin_sdk.dart';

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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
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

class VolunteerMessagesScreen extends StatefulWidget {
  const VolunteerMessagesScreen({super.key});

  @override
  State<VolunteerMessagesScreen> createState() =>
      _VolunteerMessagesScreenState();
}

class _VolunteerMessagesScreenState extends State<VolunteerMessagesScreen> {
  bool loading = true;
  String? error;
  List<VolunteerContactMessage> messages = [];
  StreamSubscription<List<VolunteerContactMessage>>? messagesSubscription;

  @override
  void initState() {
    super.initState();
    startMessagesListener();
  }

  @override
  void dispose() {
    messagesSubscription?.cancel();
    super.dispose();
  }

  void startMessagesListener() {
    setState(() {
      loading = true;
      error = null;
    });

    messagesSubscription?.cancel();

    messagesSubscription =
        VolunteerContactAdminSdk.watchVolunteerMessages().listen(
      (result) {
        if (!mounted) return;

        setState(() {
          messages = result;
          loading = false;
          error = null;
        });
      },
      onError: (e) {
        if (!mounted) return;

        setState(() {
          error = e.toString();
          loading = false;
        });
      },
    );
  }

  Future<void> fetchMessages() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await VolunteerContactAdminSdk.getVolunteerMessages();

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
      MaterialPageRoute(builder: (_) => const SendVolunteerMessageScreen()),
    );

    if (created == true) {
      await fetchMessages();
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

    await fetchMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        title: const Text('My Admin Messages'),
        actions: [
          IconButton(onPressed: fetchMessages, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.maroon,
        foregroundColor: AppColors.white,
        onPressed: openSendScreen,
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
      return ErrorState(message: error!, onRetry: startMessagesListener);
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
      await VolunteerContactAdminSdk.sendMessageToAdmin(
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
      appBar: AppBar(title: const Text('Contact Admin')),
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
  bool loading = true;
  String? error;
  List<VolunteerContactMessage> contacts = [];
  StreamSubscription<List<VolunteerContactMessage>>? contactsSubscription;

  int get unreadCount =>
      contacts.where((item) => item.isReadByAdmin == false).length;

  @override
  void initState() {
    super.initState();
    startContactsListener();
  }

  @override
  void dispose() {
    contactsSubscription?.cancel();
    super.dispose();
  }

  void startContactsListener() {
    setState(() {
      loading = true;
      error = null;
    });

    contactsSubscription?.cancel();

    contactsSubscription = VolunteerContactAdminSdk.watchAdminContacts().listen(
      (result) {
        if (!mounted) return;

        setState(() {
          contacts = result;
          loading = false;
          error = null;
        });
      },
      onError: (e) {
        if (!mounted) return;

        setState(() {
          error = e.toString();
          loading = false;
        });
      },
    );
  }

  Future<void> fetchContacts() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await VolunteerContactAdminSdk.getAdminContacts();

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

    await fetchContacts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        title: const Text('Volunteer Contacts'),
        actions: [
          IconButton(onPressed: fetchContacts, icon: const Icon(Icons.refresh)),
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
      return ErrorState(message: error!, onRetry: startContactsListener);
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
        SummaryBox(total: contacts.length, unread: unreadCount),
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
  final replyController = TextEditingController();

  bool loading = true;
  bool actionLoading = false;
  String? error;
  VolunteerContactMessage? message;
  StreamSubscription<VolunteerContactMessage?>? detailSubscription;

  @override
  void initState() {
    super.initState();
    startDetailListener();
  }

  @override
  void dispose() {
    detailSubscription?.cancel();
    replyController.dispose();
    super.dispose();
  }

  void startDetailListener() {
    setState(() {
      loading = true;
      error = null;
    });

    detailSubscription?.cancel();

    final stream = widget.isAdminView
        ? VolunteerContactAdminSdk.watchAdminContactDetail(widget.contactId)
        : VolunteerContactAdminSdk.watchVolunteerMessageDetail(
            widget.contactId,
          );

    detailSubscription = stream.listen(
      (result) {
        if (!mounted) return;

        setState(() {
          message = result;
          loading = false;
          error = null;
        });
      },
      onError: (e) {
        if (!mounted) return;

        setState(() {
          error = e.toString();
          loading = false;
        });
      },
    );
  }

  Future<void> fetchDetail() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = widget.isAdminView
          ? await VolunteerContactAdminSdk.getAdminContactDetail(
              widget.contactId,
            )
          : await VolunteerContactAdminSdk.getVolunteerMessageDetail(
              widget.contactId,
            );

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
      await VolunteerContactAdminSdk.markAdminContactAsRead(widget.contactId);

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
      await VolunteerContactAdminSdk.replyToVolunteer(
        contactId: widget.contactId,
        reply: reply,
      );

      if (!mounted) return;

      replyController.clear();

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
      appBar: AppBar(title: Text(title)),
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
      return ErrorState(message: error!, onRetry: startDetailListener);
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
                    if (!widget.isAdminView &&
                        item.adminReply.trim().isNotEmpty &&
                        item.isReadByVolunteer == false) ...[
                      const SizedBox(width: 8),
                      const StatusBadge(
                        text: 'New Reply',
                        color: AppColors.danger,
                      ),
                    ],
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
    final hasUnreadVolunteerReply =
        !isAdminView && hasReply && item.isReadByVolunteer == false;

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
                      if (hasUnreadVolunteerReply)
                        const StatusBadge(
                          text: 'New Reply',
                          color: AppColors.danger,
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

  const SummaryBox({super.key, required this.total, required this.unread});

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
          Container(height: 44, width: 1, color: AppColors.border),
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
            Text(title, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ],
    );
  }
}

class CardContainer extends StatelessWidget {
  final Widget child;

  const CardContainer({super.key, required this.child});

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

  const StatusBadge({super.key, required this.text, required this.color});

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

  const InfoRow({super.key, required this.label, required this.value});

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
          ElevatedButton(onPressed: onPressed, child: Text(buttonText!)),
        ],
      ],
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 90),
        const Icon(Icons.error_outline, size: 76, color: AppColors.danger),
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