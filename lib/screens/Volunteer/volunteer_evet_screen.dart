// lib/screens/Volunteer/volunteer_event_screen.dart

import 'package:flutter/material.dart';

import 'package:blood_donation_app/sdk/core/sdk_exception.dart';
import 'package:blood_donation_app/sdk/volunteer/volunteer_event_sdk.dart';

class VolunteerEvetScreen extends StatefulWidget {
  const VolunteerEvetScreen({super.key});

  @override
  State<VolunteerEvetScreen> createState() => _VolunteerEvetScreenState();
}

class _VolunteerEvetScreenState extends State<VolunteerEvetScreen> {
  bool _loading = true;
  String? _error;
  List<EventModel> _events = [];

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final events = await VolunteerEventSdk.fetchEvents();

      if (!mounted) return;

      setState(() {
        _events = events;
        _loading = false;
      });
    } on SdkException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _openDetailPage(EventModel event) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailPage(eventId: event.eventId),
      ),
    );

    if (!mounted) return;

    await _fetchEvents();
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.maroon),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.maroon,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchEvents,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maroon,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_events.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_busy_outlined,
                size: 58,
                color: AppColors.maroon,
              ),
              SizedBox(height: 14),
              Text(
                'No events found',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'No blood events are available right now.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.maroon,
      onRefresh: _fetchEvents,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _events.length,
        itemBuilder: (context, index) {
          final event = _events[index];

          return EventCard(
            event: event,
            onTap: () => _openDetailPage(event),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Blood Events',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _fetchEvents,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}

/* ============================================================
   EVENT DETAIL PAGE
============================================================ */

class EventDetailPage extends StatefulWidget {
  final String eventId;

  const EventDetailPage({
    super.key,
    required this.eventId,
  });

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  bool _loading = true;
  String? _error;
  EventModel? _event;

  @override
  void initState() {
    super.initState();
    _fetchEventDetail();
  }

  Future<void> _fetchEventDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final event = await VolunteerEventSdk.fetchEventDetail(widget.eventId);

      if (!mounted) return;

      setState(() {
        _event = event;
        _loading = false;
      });
    } on SdkException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.maroon),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.maroon,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchEventDetail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maroon,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final event = _event;

    if (event == null) {
      return const Center(child: Text('Event not found'));
    }

    return RefreshIndicator(
      color: AppColors.maroon,
      onRefresh: _fetchEventDetail,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          EventBanner(url: event.bannerUrl, height: 245),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EventStatusChip(status: event.status),
                const SizedBox(height: 12),
                Text(
                  event.title.isEmpty ? 'Untitled Event' : event.title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  event.description.isEmpty
                      ? 'No description available.'
                      : event.description,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                DetailTile(
                  icon: Icons.location_on_outlined,
                  title: 'Location',
                  value: event.location,
                ),
                DetailTile(
                  icon: Icons.calendar_month_outlined,
                  title: 'Date',
                  value: event.date,
                ),
                DetailTile(
                  icon: Icons.access_time,
                  title: 'Time',
                  value: event.time,
                ),
                DetailTile(
                  icon: Icons.person_outline,
                  title: 'Organizer',
                  value: event.organizer,
                ),
                DetailTile(
                  icon: Icons.bloodtype_outlined,
                  title: 'Blood Group Needed',
                  value: event.bloodGroupNeeded.isEmpty
                      ? 'Any'
                      : event.bloodGroupNeeded,
                ),
                DetailTile(
                  icon: Icons.groups_2_outlined,
                  title: 'Max Volunteers',
                  value: event.maxVolunteers == 0
                      ? 'N/A'
                      : event.maxVolunteers.toString(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
        title: const Text(
          'Event Detail',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _buildBody(),
    );
  }
}

/* ============================================================
   REUSABLE UI WIDGETS
============================================================ */

class EventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback onTap;

  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            EventBanner(url: event.bannerUrl, height: 165),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      EventStatusChip(status: event.status),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 15,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    event.title.isEmpty ? 'Untitled Event' : event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.description.isEmpty
                        ? 'No description available.'
                        : event.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  MiniInfo(
                    icon: Icons.location_on_outlined,
                    text: event.location,
                  ),
                  const SizedBox(height: 6),
                  MiniInfo(
                    icon: Icons.calendar_month_outlined,
                    text: '${event.date}  ${event.time}',
                  ),
                  const SizedBox(height: 6),
                  MiniInfo(
                    icon: Icons.bloodtype_outlined,
                    text: event.bloodGroupNeeded.isEmpty
                        ? 'Blood group: Any'
                        : 'Blood group: ${event.bloodGroupNeeded}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EventBanner extends StatelessWidget {
  final String url;
  final double height;

  const EventBanner({
    super.key,
    required this.url,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return BannerPlaceholder(height: height);
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(20),
      ),
      child: Image.network(
        url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return BannerPlaceholder(height: height);
        },
      ),
    );
  }
}

class BannerPlaceholder extends StatelessWidget {
  final double height;

  const BannerPlaceholder({
    super.key,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.lightMaroonBg,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.event_available_outlined,
          size: 58,
          color: AppColors.maroon,
        ),
      ),
    );
  }
}

class MiniInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const MiniInfo({
    super.key,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.maroon),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text.trim().isEmpty ? 'N/A' : text,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class DetailTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const DetailTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.maroon, size: 23),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value.trim().isEmpty ? 'N/A' : value,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
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

class EventStatusChip extends StatelessWidget {
  final String status;

  const EventStatusChip({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase().trim();

    Color bg;
    Color textColor;

    if (normalized == 'active' || normalized == 'upcoming') {
      bg = const Color(0xFFE8F5EE);
      textColor = AppColors.success;
    } else if (normalized == 'cancelled') {
      bg = const Color(0xFFFDECEC);
      textColor = AppColors.danger;
    } else {
      bg = const Color(0xFFFFF3CD);
      textColor = const Color(0xFF856404);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status.isEmpty ? 'N/A' : status,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/* ============================================================
   COLORS
============================================================ */

class AppColors {
  static const Color maroon = Color(0xFF7B1020);
  static const Color maroonDark = Color(0xFF5C0B17);
  static const Color maroonLight = Color(0xFFA32238);

  static const Color white = Colors.white;
  static const Color softWhite = Color(0xFFFAF7F8);
  static const Color lightMaroonBg = Color(0xFFF5E8EB);
  static const Color border = Color(0xFFEAD8DC);

  static const Color text = Color(0xFF2D1F22);
  static const Color muted = Color(0xFF7B6B70);

  static const Color success = Color(0xFF198754);
  static const Color danger = Color(0xFFDC3545);
}