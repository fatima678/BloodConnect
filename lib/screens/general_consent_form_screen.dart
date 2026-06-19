// lib/screens/general/general_consent_form_screen.dart

import 'package:flutter/material.dart';

import 'package:blood_donation_app/theme.dart';
import 'package:blood_donation_app/sdk/core/sdk_exception.dart';
import 'package:blood_donation_app/sdk/donation_request_sdk.dart';

class GeneralConsentFormScreen extends StatefulWidget {
  final String donationRequestId;
  final Map<String, dynamic> requestData;

  const GeneralConsentFormScreen({
    super.key,
    required this.donationRequestId,
    required this.requestData,
  });

  @override
  State<GeneralConsentFormScreen> createState() =>
      _GeneralConsentFormScreenState();
}

class _GeneralConsentFormScreenState extends State<GeneralConsentFormScreen>
    with SingleTickerProviderStateMixin {
  bool _isAgreed = false;
  bool _isSubmitting = false;
  bool _showSuccessCard = false;

  final TextEditingController _messageController = TextEditingController();

  late final AnimationController _successAnimationController;
  late final Animation<double> _successScaleAnimation;
  late final Animation<double> _successFadeAnimation;

  @override
  void initState() {
    super.initState();

    _successAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _successScaleAnimation = CurvedAnimation(
      parent: _successAnimationController,
      curve: Curves.elasticOut,
    );

    _successFadeAnimation = CurvedAnimation(
      parent: _successAnimationController,
      curve: Curves.easeIn,
    );
  }

  String _readString(List<String> keys) {
    for (final key in keys) {
      final value = widget.requestData[key];

      if (value == null) continue;

      final text = value.toString().trim();

      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }

    return '';
  }

  Future<void> _showSuccessAndRedirect() async {
    if (!mounted) return;

    setState(() {
      _showSuccessCard = true;
    });

    _successAnimationController.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 1600));

    if (!mounted) return;

    setState(() {
      _showSuccessCard = false;
    });

    Navigator.pop(context, true);
  }

  Future<void> _submitConsent() async {
    if (_isSubmitting || _showSuccessCard) return;

    if (!_isAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please agree to the consent terms."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _isSubmitting = true);

    try {
      await DonationRequestFlowSdk.acceptRequestWithConsent(
        donationRequestId: widget.donationRequestId,
        donorMessage: _messageController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();

      setState(() => _isSubmitting = false);

      await _showSuccessAndRedirect();
    } on SdkException catch (e) {
      if (!mounted) return;

      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSuccessCard() {
    return FadeTransition(
      opacity: _successFadeAnimation,
      child: ScaleTransition(
        scale: _successScaleAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 380),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(
              color: const Color(0xFFE9F8EF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.green.withOpacity(0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.green,
                  child: Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  "Consent submitted successfully.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "Recipient has been notified.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool disableForm = _isSubmitting || _showSuccessCard;

    final String patientName = _readString(
      ['patient_name', 'patientName'],
    ).isEmpty
        ? "Recipient"
        : _readString(['patient_name', 'patientName']);

    final String bloodGroup = _readString(
      ['patient_blood_group', 'blood_group', 'bloodGroup'],
    ).isEmpty
        ? "Required"
        : _readString(['patient_blood_group', 'blood_group', 'bloodGroup']);

    final String patientLocation = _readString(
      ['patient_location', 'location', 'address', 'current_location'],
    ).isEmpty
        ? "Location not available"
        : _readString(['patient_location', 'location', 'address', 'current_location']);

    final String message = _readString(['message']);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Donation Consent"),
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: disableForm ? null : () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: disableForm,
            child: SingleChildScrollView(
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
                  const SizedBox(height: 18),
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
                        _buildInfoRow("Recipient", patientName),
                        _buildInfoRow("Blood Group", bloodGroup),
                        _buildInfoRow("Location", patientLocation),
                        if (message.isNotEmpty) _buildInfoRow("Message", message),
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
                    "• I am willingly donating my blood to help the recipient.\n"
                    "• I have not donated blood in the last 3 months.\n"
                    "• I am physically and medically fit for donation.\n"
                    "• I understand the risks and procedures of blood donation.\n"
                    "• I allow my contact details to be shared with the recipient.",
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
                    onChanged: disableForm
                        ? null
                        : (value) {
                            setState(() => _isAgreed = value ?? false);
                          },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _messageController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Message for Recipient (Optional)",
                      hintText: "E.g., I can reach in 2 hours...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: disableForm ? null : _submitConsent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryMaroon,
                        disabledBackgroundColor: primaryMaroon.withOpacity(0.65),
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
                ],
              ),
            ),
          ),
          if (_showSuccessCard)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.18),
                alignment: Alignment.center,
                child: _buildSuccessCard(),
              ),
            ),
        ],
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
            width: 105,
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
    _successAnimationController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}