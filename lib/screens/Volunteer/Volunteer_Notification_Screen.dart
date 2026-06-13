import 'package:flutter/material.dart';

import '../../sdk/volunteer/volunteer_notification_sdk.dart';

class VolunteerNotificationScreen extends StatelessWidget {
  final String? authToken;

  const VolunteerNotificationScreen({super.key, this.authToken});

  @override
  Widget build(BuildContext context) {
    return VolunteerNotificationPage(authToken: authToken);
  }
}

class VolunteerNotificationPage extends StatefulWidget {
  final String? authToken;

  const VolunteerNotificationPage({super.key, this.authToken});

  @override
  State<VolunteerNotificationPage> createState() =>
      _VolunteerNotificationPageState();
}

class _VolunteerNotificationPageState extends State<VolunteerNotificationPage> {
  static const Color _maroon = Color(0xFF7B1020);
  static const Color _maroonDark = Color(0xFF5C0B17);
  static const Color _softWhite = Color(0xFFFAF7F8);
  static const Color _borderColor = Color(0xFFEAD8DC);

  late Future<List<VolunteerNotificationModel>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _fetchNotifications();
  }

  Future<List<VolunteerNotificationModel>> _fetchNotifications() async {
    return VolunteerNotificationSdk.fetchNotifications();
  }

  Future<void> _markAsRead(String notificationId) async {
    if (notificationId.isEmpty) return;

    try {
      await VolunteerNotificationSdk.markAsRead(notificationId);
    } catch (_) {
      // Silent fail. Detail screen should still open.
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _notificationsFuture = _fetchNotifications();
    });

    await _notificationsFuture;
  }

  void _openDetail(VolunteerNotificationModel notification) async {
    await _markAsRead(notification.notificationId);

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VolunteerNotificationDetailPage(
          notification: notification,
          authToken: widget.authToken,
        ),
      ),
    );

    if (!mounted) return;

    setState(() {
      _notificationsFuture = _fetchNotifications();
    });
  }

  bool _isAuthError(Object error) {
    final message = error.toString().toLowerCase();

    return message.contains('session') ||
        message.contains('login') ||
        message.contains('volunteer profile') ||
        message.contains('permission') ||
        message.contains('unauthenticated') ||
        message.contains('invalid');
  }

  void _goToLogin() {
    if (!mounted) return;

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil('/volunteer-login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _softWhite,
      appBar: AppBar(
        backgroundColor: _maroon,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Volunteer Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<VolunteerNotificationModel>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _maroon),
            );
          }

          if (snapshot.hasError) {
            final isAuthError = _isAuthError(snapshot.error!);

            return _ErrorView(
              message: snapshot.error.toString().replaceFirst(
                'Exception: ',
                '',
              ),
              onRetry: () {
                setState(() {
                  _notificationsFuture = _fetchNotifications();
                });
              },
              onLogin: isAuthError ? _goToLogin : null,
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return RefreshIndicator(
              color: _maroon,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 140),
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 80,
                    color: _maroon,
                  ),
                  SizedBox(height: 18),
                  Center(
                    child: Text(
                      'No notifications found.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final unreadCount = notifications
              .where((item) => !item.isRead)
              .length;

          return RefreshIndicator(
            color: _maroon,
            onRefresh: _refresh,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: _borderColor)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Total: ${notifications.length}',
                          style: const TextStyle(
                            color: _maroonDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: unreadCount > 0
                              ? _maroon.withOpacity(0.08)
                              : Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          'Unread: $unreadCount',
                          style: TextStyle(
                            color: unreadCount > 0 ? _maroon : Colors.green,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = notifications[index];

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openDetail(item),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: item.isRead
                                  ? _borderColor
                                  : _maroon.withOpacity(0.35),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: _maroon.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.bloodtype_rounded,
                                      color: _maroon,
                                      size: 28,
                                    ),
                                  ),
                                  if (!item.isRead)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        width: 11,
                                        height: 11,
                                        decoration: BoxDecoration(
                                          color: _maroon,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.displayTitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _maroonDark,
                                        fontSize: 16,
                                        fontWeight: item.isRead
                                            ? FontWeight.w600
                                            : FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      item.message.isNotEmpty
                                          ? item.message
                                          : 'Tap to view full detail.',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 13.5,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 9),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        if (item.bloodGroup.isNotEmpty)
                                          _SmallChip(
                                            text: item.bloodGroup,
                                            icon: Icons.water_drop_rounded,
                                          ),
                                        if (item.location.isNotEmpty)
                                          _SmallChip(
                                            text: item.location,
                                            icon: Icons.location_on_rounded,
                                          ),
                                        if (item.readableDate.isNotEmpty)
                                          _SmallChip(
                                            text: item.readableDate,
                                            icon: Icons.calendar_month_rounded,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: Colors.black38,
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
        },
      ),
    );
  }
}

class VolunteerNotificationDetailPage extends StatefulWidget {
  final VolunteerNotificationModel notification;
  final String? authToken;

  const VolunteerNotificationDetailPage({
    super.key,
    required this.notification,
    this.authToken,
  });

  @override
  State<VolunteerNotificationDetailPage> createState() =>
      _VolunteerNotificationDetailPageState();
}

class _VolunteerNotificationDetailPageState
    extends State<VolunteerNotificationDetailPage> {
  static const Color _maroon = Color(0xFF7B1020);
  static const Color _maroonDark = Color(0xFF5C0B17);
  static const Color _softWhite = Color(0xFFFAF7F8);
  static const Color _borderColor = Color(0xFFEAD8DC);

  late Future<Map<String, dynamic>> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetail();
  }

  Future<Map<String, dynamic>> _loadDetail() async {
    return VolunteerNotificationSdk.loadNotificationDetail(widget.notification);
  }

  String _first(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];

      if (value == null) continue;

      final text = value.toString().trim();

      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }

    return '';
  }

  String _formatDate(String raw) {
    if (raw.trim().isEmpty) return '';

    try {
      final dt = DateTime.tryParse(raw);
      if (dt == null) return raw;

      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();

      int hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final amPm = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;

      return '$day-$month-$year  $hour:$minute $amPm';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _softWhite,
      appBar: AppBar(
        backgroundColor: _maroon,
        elevation: 0,
        title: const Text(
          'Notification Detail',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _maroon),
            );
          }

          final data = snapshot.data ?? widget.notification.raw;

          final title = _first(data, [
            'event_title',
            'eventTitle',
            'blood_bank_title',
            'bloodBankTitle',
            'blood_bank_name',
            'bloodBankName',
            'hospital_name',
            'hospitalName',
            'title',
            'name',
          ]);

          final imageUrl = _first(data, [
            'image_url',
            'imageUrl',
            'event_image_url',
            'eventImageUrl',
            'event_image',
            'eventImage',
            'image',
            'img_url',
            'imgUrl',
            'banner_url',
            'bannerUrl',
            'banner',
            'photo_url',
            'photoUrl',
            'thumbnail',
            'cloudinary_url',
            'cloudinaryUrl',
            'secure_url',
            'secureUrl',
          ]);

          final message = _first(data, [
            'message',
            'short_message',
            'shortMessage',
          ]);

          final description = _first(data, [
            'description',
            'event_description',
            'eventDescription',
            'case_description',
            'caseDescription',
            'details',
            'detail',
          ]);

          final organizer = _first(data, [
            'organizer',
            'organizer_name',
            'organizerName',
            'admin_name',
            'adminName',
            'created_by',
            'createdBy',
          ]);

          final bloodBank = _first(data, [
            'blood_bank_title',
            'bloodBankTitle',
            'blood_bank_name',
            'bloodBankName',
            'hospital_name',
            'hospitalName',
            'bank_name',
            'bankName',
          ]);

          final bloodGroup = _first(data, [
            'blood_group',
            'bloodGroup',
            'blood_type',
            'bloodType',
            'required_blood_group',
            'requiredBloodGroup',
          ]);

          final location = _first(data, [
            'location',
            'address',
            'city',
            'venue',
          ]);

          final date = _first(data, [
            'date',
            'event_date',
            'eventDate',
            'created_at',
            'createdAt',
          ]);

          final time = _first(data, ['time', 'event_time', 'eventTime']);

          final phone = _first(data, [
            'phone',
            'phone_number',
            'phoneNumber',
            'contact',
            'contact_number',
            'contactNumber',
            'mobile',
          ]);

          final status = _first(data, [
            'status',
            'event_status',
            'eventStatus',
          ]);

          final type = _first(data, [
            'type',
            'notification_type',
            'notificationType',
          ]);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _ImagePlaceholder(),
                    ),
                  )
                else
                  _ImagePlaceholder(),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isNotEmpty ? title : 'Notification Detail',
                        style: const TextStyle(
                          color: _maroonDark,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      if (message.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          message,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _DetailCard(
                  title: 'Important Information',
                  children: [
                    if (bloodBank.isNotEmpty)
                      _DetailRow(
                        icon: Icons.local_hospital_rounded,
                        label: 'Blood Bank / Hospital',
                        value: bloodBank,
                      ),
                    if (bloodGroup.isNotEmpty)
                      _DetailRow(
                        icon: Icons.water_drop_rounded,
                        label: 'Blood Group',
                        value: bloodGroup,
                      ),
                    if (organizer.isNotEmpty)
                      _DetailRow(
                        icon: Icons.person_rounded,
                        label: 'Organizer',
                        value: organizer,
                      ),
                    if (location.isNotEmpty)
                      _DetailRow(
                        icon: Icons.location_on_rounded,
                        label: 'Location',
                        value: location,
                      ),
                    if (date.isNotEmpty)
                      _DetailRow(
                        icon: Icons.calendar_month_rounded,
                        label: 'Date',
                        value: _formatDate(date),
                      ),
                    if (time.isNotEmpty)
                      _DetailRow(
                        icon: Icons.access_time_rounded,
                        label: 'Time',
                        value: time,
                      ),
                    if (phone.isNotEmpty)
                      _DetailRow(
                        icon: Icons.phone_rounded,
                        label: 'Contact',
                        value: phone,
                      ),
                    if (status.isNotEmpty)
                      _DetailRow(
                        icon: Icons.verified_rounded,
                        label: 'Status',
                        value: status,
                      ),
                    if (type.isNotEmpty)
                      _DetailRow(
                        icon: Icons.notifications_rounded,
                        label: 'Type',
                        value: type,
                      ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Description',
                          style: TextStyle(
                            color: _maroonDark,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          description,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String text;
  final IconData icon;

  const _SmallChip({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    const Color maroon = Color(0xFF7B1020);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: maroon.withOpacity(0.07),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: maroon),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: maroon,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    const Color maroonDark = Color(0xFF5C0B17);
    const Color borderColor = Color(0xFFEAD8DC);

    final visibleChildren = children
        .where((item) => item is! SizedBox)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: maroonDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (visibleChildren.isEmpty)
            const Text(
              'No extra information available.',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            )
          else
            ...visibleChildren,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    const Color maroon = Color(0xFF7B1020);

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: maroon.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: maroon, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const Color maroon = Color(0xFF7B1020);

    return Container(
      width: double.infinity,
      height: 210,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAD8DC)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bloodtype_rounded, size: 64, color: maroon),
          SizedBox(height: 10),
          Text(
            'Blood Connect Notification',
            style: TextStyle(
              color: maroon,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onLogin;

  const _ErrorView({
    required this.message,
    required this.onRetry,
    this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    const Color maroon = Color(0xFF7B1020);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: maroon, size: 62),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: maroon,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (onLogin != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: onLogin,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Login Again'),
                style: TextButton.styleFrom(foregroundColor: maroon),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
