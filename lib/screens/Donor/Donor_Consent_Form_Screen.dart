// lib/screens/consent_form_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:blood_donation_app/theme.dart';
import 'package:blood_donation_app/services/auth_token_service.dart';

class ConsentFormScreen extends StatefulWidget {
  static const String routeName = '/consent_form';

  final String patientName;
  final String bloodGroup;
  final String patientLocation;
  final String? patientMessage;
  final String requestId;

  const ConsentFormScreen({
    super.key,
    required this.patientName,
    required this.bloodGroup,
    required this.patientLocation,
    this.patientMessage,
    required this.requestId,
  });

  @override
  State<ConsentFormScreen> createState() => _ConsentFormScreenState();
}

class _ConsentFormScreenState extends State<ConsentFormScreen> {
  bool _isAgreed = false;
  bool _isSubmitting = false;

  final TextEditingController _messageController = TextEditingController();

  Future<void> _submitConsent() async {
    if (!_isAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please agree to the consent terms."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.requestId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Donation request ID is missing."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await AuthTokenService.authorizedPost(
        '/donation-requests/${widget.requestId}/accept',
        {
          "consent_data": {
            "agreed": true,
            "donor_message": _messageController.text.trim(),
            "is_willing_to_donate": true,
            "accepted_terms": true,
          },
        },
      );

      debugPrint("Consent Accept Status: ${response.statusCode}");
      debugPrint("Consent Accept Body: ${response.body}");

      Map<String, dynamic> body = {};

      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = {};
      }

      if (!mounted) return;

      setState(() => _isSubmitting = false);

      if (response.statusCode == 200 && body['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              body['message'] ??
                  "Request accepted successfully. Patient has been notified.",
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(body['message'] ?? "Failed to submit consent."),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Connection Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String patientName = widget.patientName.trim().isEmpty
        ? "Patient"
        : widget.patientName.trim();

    final String bloodGroup = widget.bloodGroup.trim().isEmpty
        ? "Required"
        : widget.bloodGroup.trim();

    final String patientLocation = widget.patientLocation.trim().isEmpty
        ? "Location not available"
        : widget.patientLocation.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Blood Donation Consent"),
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Icon(
                Icons.volunteer_activism,
                size: 90,
                color: Color(0xFF6B0000),
              ),
            ),

            const SizedBox(height: 20),

            const Center(
              child: Text(
                "Will you donate blood?",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "Patient Request",
              style: TextStyle(fontSize: 18, color: Colors.grey[700]),
            ),

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow("Patient Name", patientName),
                  _buildInfoRow("Blood Group", bloodGroup),
                  _buildInfoRow("Location", patientLocation),
                  if (widget.patientMessage != null &&
                      widget.patientMessage!.trim().isNotEmpty)
                    _buildInfoRow("Message", widget.patientMessage!.trim()),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              "Consent Declaration",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            const Text(
              "I hereby declare that:\n\n"
              "• I am willingly donating my blood to help the patient.\n"
              "• I have not donated blood in the last 3 months.\n"
              "• I am physically and medically fit for donation.\n"
              "• I understand the risks and procedures of blood donation.\n"
              "• I allow my contact details to be shared with the patient.",
              style: TextStyle(fontSize: 16, height: 1.7),
            ),

            const SizedBox(height: 20),

            CheckboxListTile(
              title: const Text(
                "I have read and fully agree to the above terms and conditions.",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              value: _isAgreed,
              activeColor: primaryMaroon,
              onChanged: (value) {
                setState(() => _isAgreed = value ?? false);
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Message for Patient (Optional)",
                hintText: "E.g., I can reach in 2 hours...",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitConsent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryMaroon,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Yes, I Want to Donate",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade400),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "No, Decline Request",
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}