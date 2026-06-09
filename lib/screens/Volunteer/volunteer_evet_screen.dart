import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VolunteerEvetScreen extends StatefulWidget {
  const VolunteerEvetScreen({super.key});

  @override
  State<VolunteerEvetScreen> createState() => _VolunteerEvetScreenState();
}

class _VolunteerEvetScreenState extends State<VolunteerEvetScreen> {
  final EventApiService _api = EventApiService();

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
      final events = await _api.getEvents();

      if (!mounted) return;

      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _openCreatePage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EventFormPage(),
      ),
    );

    if (result == true) {
      _fetchEvents();
    }
  }

  Future<void> _openDetailPage(EventModel event) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailPage(eventId: event.eventId),
      ),
    );

    if (result == true) {
      _fetchEvents();
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.event_busy_outlined,
                size: 58,
                color: AppColors.maroon,
              ),
              const SizedBox(height: 14),
              const Text(
                'No events found',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create your first blood event from admin panel.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _openCreatePage,
                icon: const Icon(Icons.add),
                label: const Text('Create Event'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maroon,
                  foregroundColor: Colors.white,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreatePage,
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Event'),
      ),
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
  final EventApiService _api = EventApiService();

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
      final event = await _api.getEventDetail(widget.eventId);

      if (!mounted) return;

      setState(() {
        _event = event;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _openEditPage() async {
    if (_event == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventFormPage(event: _event),
      ),
    );

    if (result == true) {
      _fetchEventDetail();
    }
  }

  Future<void> _deleteEvent() async {
    if (_event == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Delete Event'),
          content: Text('Are you sure you want to delete "${_event!.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _api.deleteEvent(_event!.eventId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event deleted successfully')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
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
                  event.title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  event.description,
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
                  value: event.maxVolunteers.toString(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openEditPage,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Update'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.maroon,
                          side: const BorderSide(color: AppColors.maroon),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _deleteEvent,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
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
   CREATE / UPDATE EVENT PAGE
============================================================ */

class EventFormPage extends StatefulWidget {
  final EventModel? event;

  const EventFormPage({
    super.key,
    this.event,
  });

  bool get isEdit => event != null;

  @override
  State<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends State<EventFormPage> {
  final _formKey = GlobalKey<FormState>();
  final EventApiService _api = EventApiService();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _dateController;
  late final TextEditingController _timeController;
  late final TextEditingController _organizerController;
  late final TextEditingController _maxVolunteersController;

  File? _selectedBanner;
  bool _saving = false;

  String _bloodGroup = '';
  String _status = 'active';

  final List<String> _bloodGroups = [
    '',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  final List<String> _statuses = [
    'active',
    'inactive',
    'completed',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();

    final event = widget.event ?? EventModel.empty();

    _titleController = TextEditingController(text: event.title);
    _descriptionController = TextEditingController(text: event.description);
    _locationController = TextEditingController(text: event.location);
    _dateController = TextEditingController(text: event.date);
    _timeController = TextEditingController(text: event.time);
    _organizerController = TextEditingController(text: event.organizer);
    _maxVolunteersController = TextEditingController(
      text: event.maxVolunteers == 0 ? '' : event.maxVolunteers.toString(),
    );

    _bloodGroup = event.bloodGroupNeeded;
    _status = event.status.isEmpty ? 'active' : event.status;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _organizerController.dispose();
    _maxVolunteersController.dispose();
    super.dispose();
  }

  Future<void> _pickBanner() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );

    if (picked == null) return;

    setState(() {
      _selectedBanner = File(picked.path);
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.maroon,
              onPrimary: Colors.white,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    _dateController.text =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.maroon,
              onPrimary: Colors.white,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    _timeController.text = picked.format(context);
  }

  EventModel _buildEventModel() {
    return EventModel(
      eventId: widget.event?.eventId ?? '',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      location: _locationController.text.trim(),
      date: _dateController.text.trim(),
      time: _timeController.text.trim(),
      organizer: _organizerController.text.trim(),
      bloodGroupNeeded: _bloodGroup,
      maxVolunteers: int.tryParse(_maxVolunteersController.text.trim()) ?? 0,
      status: _status,
      bannerUrl: widget.event?.bannerUrl ?? '',
    );
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
    });

    try {
      final event = _buildEventModel();

      if (widget.isEdit) {
        await _api.updateEvent(
          eventId: widget.event!.eventId,
          event: event,
          bannerFile: _selectedBanner,
        );
      } else {
        await _api.createEvent(
          event: event,
          bannerFile: _selectedBanner,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEdit
                ? 'Event updated successfully'
                : 'Event created successfully',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }

    return null;
  }

  String? _numberRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }

    final number = int.tryParse(value.trim());

    if (number == null || number <= 0) {
      return 'Enter valid number';
    }

    return null;
  }

  Widget _input({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onTap,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onTap: onTap,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.maroon),
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: AppColors.muted),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.maroon, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.danger),
          ),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    final safeValue = items.contains(value) ? value : items.first;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(item.isEmpty ? 'Any' : item),
          );
        }).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.maroon),
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: AppColors.muted),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.maroon, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _bannerPicker() {
    final oldUrl = widget.event?.bannerUrl ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(18),
            ),
            child: _selectedBanner != null
                ? Image.file(
                    _selectedBanner!,
                    height: 175,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : oldUrl.isNotEmpty
                    ? Image.network(
                        oldUrl,
                        height: 175,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const BannerPlaceholder(
                          height: 175,
                        ),
                      )
                    : const BannerPlaceholder(height: 175),
          ),
          TextButton.icon(
            onPressed: _pickBanner,
            icon: const Icon(Icons.image_outlined),
            label: Text(
              _selectedBanner == null ? 'Choose Banner Image' : 'Change Banner',
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.maroon,
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
        title: Text(
          widget.isEdit ? 'Update Event' : 'Create Event',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _bannerPicker(),
              _input(
                controller: _titleController,
                label: 'Event Title',
                icon: Icons.event_outlined,
                validator: _required,
              ),
              _input(
                controller: _descriptionController,
                label: 'Description',
                icon: Icons.description_outlined,
                maxLines: 4,
                validator: _required,
              ),
              _input(
                controller: _locationController,
                label: 'Location',
                icon: Icons.location_on_outlined,
                validator: _required,
              ),
              _input(
                controller: _dateController,
                label: 'Date',
                icon: Icons.calendar_month_outlined,
                readOnly: true,
                onTap: _pickDate,
                validator: _required,
              ),
              _input(
                controller: _timeController,
                label: 'Time',
                icon: Icons.access_time,
                readOnly: true,
                onTap: _pickTime,
                validator: _required,
              ),
              _input(
                controller: _organizerController,
                label: 'Organizer',
                icon: Icons.person_outline,
                validator: _required,
              ),
              _dropdown(
                label: 'Blood Group Needed',
                icon: Icons.bloodtype_outlined,
                value: _bloodGroup,
                items: _bloodGroups,
                onChanged: (value) {
                  setState(() {
                    _bloodGroup = value ?? '';
                  });
                },
              ),
              _input(
                controller: _maxVolunteersController,
                label: 'Max Volunteers',
                icon: Icons.groups_2_outlined,
                keyboardType: TextInputType.number,
                validator: _numberRequired,
              ),
              _dropdown(
                label: 'Status',
                icon: Icons.info_outline,
                value: _status,
                items: _statuses,
                onChanged: (value) {
                  setState(() {
                    _status = value ?? 'active';
                  });
                },
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _saving ? null : _saveEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maroon,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.maroon.withOpacity(0.45),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.isEdit ? 'Update Event' : 'Create Event',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ============================================================
   API SERVICE
============================================================ */

class EventApiService {
  static const String baseUrl =
      'https://manliness-smugness-qualm.ngrok-free.dev/api';

  static const String eventsUrl = '$baseUrl/admin/events';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('admin_token') ??
        prefs.getString('auth_token') ??
        prefs.getString('token');
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();

    if (token == null || token.trim().isEmpty) {
      throw Exception('Admin token missing. Please login again.');
    }

    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  Future<List<EventModel>> getEvents() async {
    final response = await http.get(
      Uri.parse(eventsUrl),
      headers: {
        'Accept': 'application/json',
      },
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200 && body['success'] == true) {
      final List list = body['data'] ?? [];
      return list.map((item) => EventModel.fromJson(item)).toList();
    }

    throw Exception(body['message'] ?? 'Failed to fetch events');
  }

  Future<EventModel> getEventDetail(String eventId) async {
    final response = await http.get(
      Uri.parse('$eventsUrl/$eventId'),
      headers: {
        'Accept': 'application/json',
      },
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200 && body['success'] == true) {
      return EventModel.fromJson(body['data']);
    }

    throw Exception(body['message'] ?? 'Failed to fetch event detail');
  }

  Future<void> createEvent({
    required EventModel event,
    File? bannerFile,
  }) async {
    final headers = await _authHeaders();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(eventsUrl),
    );

    request.headers.addAll(headers);
    request.fields.addAll(event.toFormFields());

    if (bannerFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('banner', bannerFile.path),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final body = jsonDecode(response.body);

    if (response.statusCode != 201 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to create event');
    }
  }

  Future<void> updateEvent({
    required String eventId,
    required EventModel event,
    File? bannerFile,
  }) async {
    final token = await _getToken();

    if (token == null || token.trim().isEmpty) {
      throw Exception('Admin token missing. Please login again.');
    }

    if (bannerFile == null) {
      final response = await http.put(
        Uri.parse('$eventsUrl/$eventId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(event.toJsonBody()),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode != 200 || body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to update event');
      }

      return;
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$eventsUrl/$eventId'),
    );

    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    request.fields['_method'] = 'PUT';
    request.fields.addAll(event.toFormFields());

    request.files.add(
      await http.MultipartFile.fromPath('banner', bannerFile.path),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final body = jsonDecode(response.body);

    if (response.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to update event');
    }
  }

  Future<void> deleteEvent(String eventId) async {
    final headers = await _authHeaders();

    final response = await http.delete(
      Uri.parse('$eventsUrl/$eventId'),
      headers: headers,
    );

    final body = jsonDecode(response.body);

    if (response.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to delete event');
    }
  }
}

/* ============================================================
   MODEL
============================================================ */

class EventModel {
  final String eventId;
  final String title;
  final String description;
  final String location;
  final String date;
  final String time;
  final String organizer;
  final String bloodGroupNeeded;
  final int maxVolunteers;
  final String status;
  final String bannerUrl;

  EventModel({
    required this.eventId,
    required this.title,
    required this.description,
    required this.location,
    required this.date,
    required this.time,
    required this.organizer,
    required this.bloodGroupNeeded,
    required this.maxVolunteers,
    required this.status,
    required this.bannerUrl,
  });

  factory EventModel.empty() {
    return EventModel(
      eventId: '',
      title: '',
      description: '',
      location: '',
      date: '',
      time: '',
      organizer: '',
      bloodGroupNeeded: '',
      maxVolunteers: 0,
      status: 'active',
      bannerUrl: '',
    );
  }

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      eventId: (json['event_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      time: (json['time'] ?? '').toString(),
      organizer: (json['organizer'] ?? '').toString(),
      bloodGroupNeeded: (json['blood_group_needed'] ?? '').toString(),
      maxVolunteers: int.tryParse((json['max_volunteers'] ?? '0').toString()) ?? 0,
      status: (json['status'] ?? '').toString(),
      bannerUrl: (json['banner_url'] ?? '').toString(),
    );
  }

  Map<String, String> toFormFields() {
    return {
      'title': title,
      'description': description,
      'location': location,
      'date': date,
      'time': time,
      'organizer': organizer,
      'blood_group_needed': bloodGroupNeeded,
      'max_volunteers': maxVolunteers.toString(),
      'status': status,
    };
  }

  Map<String, dynamic> toJsonBody() {
    return {
      'title': title,
      'description': description,
      'location': location,
      'date': date,
      'time': time,
      'organizer': organizer,
      'blood_group_needed': bloodGroupNeeded,
      'max_volunteers': maxVolunteers,
      'status': status,
    };
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
                    event.description,
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

    if (normalized == 'active') {
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