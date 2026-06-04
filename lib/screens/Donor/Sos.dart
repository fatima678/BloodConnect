// lib/screens/sos_screen.dart
import 'package:flutter/material.dart';
import 'package:blood_donation_app/theme.dart';

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Emergency SOS"),
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Icon(
              Icons.emergency,
              size: 120,
              color: primaryMaroon,
            ),
            const SizedBox(height: 20),
            const Text(
              "EMERGENCY SOS",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: primaryMaroon,
              ),
            ),
            const Text(
              "Blood Connect",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 30),

            const Text(
              "This will send an urgent alert to nearby donors, volunteers, and ambulances with your current location.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),

            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: "Additional Message (Optional)",
                hintText: "e.g., Patient is bleeding heavily...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 65,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendSOS,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade900,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                ),
                child: _isSending
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "SEND SOS ALERT",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              "⚠️ This action cannot be undone",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendSOS() async {
    setState(() => _isSending = true);

    // TODO: Integrate with Firebase to send notifications to nearby users
    // TODO: Get current location and send with message

    await Future.delayed(const Duration(seconds: 2)); // Simulate network call

    if (mounted) {
      setState(() => _isSending = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🚨 SOS Alert Sent Successfully!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );

      Navigator.pop(context); // Go back after sending
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}