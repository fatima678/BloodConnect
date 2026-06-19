import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:blood_donation_app/theme.dart';
import 'package:blood_donation_app/services/auth_token_service.dart';

class SettingsScreen extends StatefulWidget {
  static const String routeName = '/settings';

  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _deleteConfirmController =
      TextEditingController();

  bool _isDeletingAccount = false;
  bool _obscurePassword = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Map<String, List<String>> _relatedCollectionFields = {
    'blood_requests': [
      'uid',
      'auth_uid',
      'user_uid',
      'user_id',
      'created_by_uid',
      'patient_uid',
      'patient_id',
      'requester_uid',
      'recipient_uid',
      'sender_uid',
    ],
    'blood_donation_requests': [
      'uid',
      'auth_uid',
      'user_uid',
      'user_id',
      'created_by_uid',
      'patient_uid',
      'patient_id',
      'donor_uid',
      'donor_id',
      'recipient_uid',
      'sender_uid',
    ],
    'donation_requests': [
      'uid',
      'auth_uid',
      'user_uid',
      'user_id',
      'created_by_uid',
      'patient_uid',
      'patient_id',
      'donor_uid',
      'donor_id',
      'recipient_uid',
      'sender_uid',
    ],
    'donor_requests': [
      'uid',
      'auth_uid',
      'user_uid',
      'user_id',
      'created_by_uid',
      'donor_uid',
      'donor_id',
      'recipient_uid',
      'sender_uid',
    ],
    'notifications': [
      'uid',
      'auth_uid',
      'user_uid',
      'user_id',
      'recipient_uid',
      'receiver_uid',
      'sender_uid',
      'patient_uid',
      'patient_id',
      'donor_uid',
      'donor_id',
    ],
    'donor_notifications': [
      'uid',
      'auth_uid',
      'user_uid',
      'user_id',
      'recipient_uid',
      'receiver_uid',
      'sender_uid',
      'patient_uid',
      'patient_id',
      'donor_uid',
      'donor_id',
    ],
    'app_feedback': [
      'uid',
      'auth_uid',
      'user_uid',
      'user_id',
    ],
    'app_ratings': [
      'uid',
      'auth_uid',
      'user_uid',
      'user_id',
    ],
  };

  static const List<String> _directUserDocumentCollections = [
    'pending_registrations',
  ];

  void _showMessage({
    required String message,
    Color backgroundColor = Colors.red,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _firebaseDeleteError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Password is incorrect. Please try again.';
      case 'user-not-found':
        return 'User account not found. Please login again.';
      case 'requires-recent-login':
        return 'For security, please login again and then delete your account.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return e.message ?? 'Failed to delete account. Please try again.';
    }
  }

  String _readString(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return '';

    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      final text = value.toString().trim();

      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }

    return '';
  }

  Future<String> _resolveUserEmail(User currentUser) async {
    final String authEmail = currentUser.email?.trim().toLowerCase() ?? '';

    if (authEmail.isNotEmpty) {
      return authEmail;
    }

    final snapshot =
        await _firestore.collection('users').doc(currentUser.uid).get();

    final String firestoreEmail = _readString(
      snapshot.data(),
      ['email'],
    ).toLowerCase();

    return firestoreEmail;
  }

  Future<void> _commitDeleteBatch(
    List<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    if (refs.isEmpty) return;

    for (int i = 0; i < refs.length; i += 400) {
      final int end = i + 400 > refs.length ? refs.length : i + 400;
      final batch = _firestore.batch();

      for (final ref in refs.sublist(i, end)) {
        batch.delete(ref);
      }

      await batch.commit();
    }
  }

  Future<void> _deleteDirectUserDocument({
    required String collectionPath,
    required String uid,
    required Set<String> deletedPaths,
    bool requiredDelete = false,
  }) async {
    final ref = _firestore.collection(collectionPath).doc(uid);

    try {
      final snapshot = await ref.get();

      if (!snapshot.exists) return;

      if (!deletedPaths.add(ref.path)) return;

      await _commitDeleteBatch([ref]);

      debugPrint('Account delete: deleted direct doc ${ref.path}');
    } on FirebaseException catch (e) {
      debugPrint(
        'Account delete direct doc failed: $collectionPath/$uid | ${e.code} | ${e.message}',
      );

      if (requiredDelete) {
        rethrow;
      }
    }
  }

  Future<void> _deleteQueryDocuments({
    required String collectionPath,
    required String field,
    required String uid,
    required Set<String> deletedPaths,
  }) async {
    try {
      while (true) {
        final snapshot = await _firestore
            .collection(collectionPath)
            .where(field, isEqualTo: uid)
            .limit(400)
            .get();

        if (snapshot.docs.isEmpty) {
          break;
        }

        final List<DocumentReference<Map<String, dynamic>>> refs = [];

        for (final doc in snapshot.docs) {
          if (deletedPaths.add(doc.reference.path)) {
            refs.add(doc.reference);
          }
        }

        if (refs.isEmpty) {
          break;
        }

        await _commitDeleteBatch(refs);

        debugPrint(
          'Account delete: deleted ${refs.length} docs from $collectionPath where $field == $uid',
        );

        if (snapshot.docs.length < 400) {
          break;
        }
      }
    } on FirebaseException catch (e) {
      debugPrint(
        'Account delete query failed: collection=$collectionPath field=$field uid=$uid code=${e.code} message=${e.message}',
      );
    }
  }

  Future<void> _deleteAllRelatedFirestoreData(String uid) async {
    final Set<String> deletedPaths = {};

    for (final entry in _relatedCollectionFields.entries) {
      for (final field in entry.value) {
        await _deleteQueryDocuments(
          collectionPath: entry.key,
          field: field,
          uid: uid,
          deletedPaths: deletedPaths,
        );
      }
    }

    for (final collectionPath in _directUserDocumentCollections) {
      await _deleteDirectUserDocument(
        collectionPath: collectionPath,
        uid: uid,
        deletedPaths: deletedPaths,
      );
    }

    await _deleteDirectUserDocument(
      collectionPath: 'users',
      uid: uid,
      deletedPaths: deletedPaths,
      requiredDelete: true,
    );
  }

  Future<void> _deleteAccount() async {
    final String password = _passwordController.text.trim();
    final String confirmText = _deleteConfirmController.text.trim();

    if (password.isEmpty) {
      _showMessage(message: 'Please enter your password.');
      return;
    }

    if (confirmText != 'DELETE') {
      _showMessage(message: 'Please type DELETE to confirm.');
      return;
    }

    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      _showMessage(message: 'Session not found. Please login again.');
      return;
    }

    if (_isDeletingAccount) return;

    setState(() {
      _isDeletingAccount = true;
    });

    try {
      final String email = await _resolveUserEmail(currentUser);

      if (email.isEmpty) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'User email not found. Please login again.',
        );
      }

      final AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      await currentUser.reauthenticateWithCredential(credential);

      await _deleteAllRelatedFirestoreData(currentUser.uid);

      await currentUser.delete();

      await AuthTokenService.clearSession();
      await _auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _isDeletingAccount = false;
      });

      _showMessage(message: _firebaseDeleteError(e));
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        _isDeletingAccount = false;
      });

      if (e.code == 'permission-denied') {
        _showMessage(
          message:
              'User account could not be deleted. Please check Firestore delete permission for users collection.',
        );
        return;
      }

      _showMessage(
        message: e.message ?? 'Failed to delete account data.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isDeletingAccount = false;
      });

      debugPrint('Account delete error: $e');

      _showMessage(message: 'Failed to delete account. Please try again.');
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    _passwordController.clear();
    _deleteConfirmController.clear();

    await showDialog<void>(
      context: context,
      barrierDismissible: !_isDeletingAccount,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Delete Account',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please review these conditions before deleting your account.',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDeletePoint('This action is permanent.'),
                    _buildDeletePoint(
                      'You must confirm ownership with your password.',
                    ),
                    _buildDeletePoint(
                      'You should not have an active emergency request in progress.',
                    ),
                    _buildDeletePoint(
                      'After confirmation, you will be logged out.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      enabled: !_isDeletingAccount,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Enter Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: _isDeletingAccount
                              ? null
                              : () {
                                  setDialogState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: primaryMaroon,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Type DELETE to continue.',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _deleteConfirmController,
                      enabled: !_isDeletingAccount,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'DELETE',
                        prefixIcon: const Icon(Icons.warning_amber_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onChanged: (_) {
                        setDialogState(() {});
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isDeletingAccount
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isDeletingAccount
                      ? null
                      : () async {
                          setDialogState(() {});
                          await _deleteAccount();
                          setDialogState(() {});
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    disabledBackgroundColor: Colors.red.withOpacity(0.55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isDeletingAccount
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.2,
                          ),
                        )
                      : const Text(
                          'Delete Account',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Widget _buildDeletePoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              color: primaryMaroon,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: primaryMaroon,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryMaroon.withOpacity(0.20),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: const Column(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.settings_outlined,
              color: primaryMaroon,
              size: 36,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Account Settings',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Manage your account preferences and security actions.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryMaroon.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'App Rules',
            style: TextStyle(
              color: primaryMaroon,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildRulePoint(
            icon: Icons.verified_user_outlined,
            title: 'Use accurate information',
            body:
                'Keep your profile, phone number, address, and blood type updated.',
          ),
          _buildRulePoint(
            icon: Icons.health_and_safety_outlined,
            title: 'Donate responsibly',
            body:
                'Accept a request only when you are willing and medically fit to donate.',
          ),
          _buildRulePoint(
            icon: Icons.notifications_active_outlined,
            title: 'Stay reachable',
            body:
                'Keep notifications enabled so donors and recipients can connect on time.',
          ),
          _buildRulePoint(
            icon: Icons.security_outlined,
            title: 'Protect your account',
            body: 'Do not share your login details or OTP with anyone.',
          ),
        ],
      ),
    );
  }

  Widget _buildRulePoint({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: primaryMaroon.withOpacity(0.10),
            child: Icon(icon, color: primaryMaroon, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13.2,
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

  Widget _buildDeleteAccountSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Account Deletion',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'You may delete your account if you no longer want to use Blood Connect. Please review the conditions before continuing.',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isDeletingAccount ? null : _showDeleteAccountDialog,
              icon: _isDeletingAccount
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.2,
                      ),
                    )
                  : const Icon(
                      Icons.delete_forever_rounded,
                      color: Colors.white,
                    ),
              label: Text(
                _isDeletingAccount
                    ? 'Deleting Account...'
                    : 'Delete Your Account',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                disabledBackgroundColor: Colors.red.withOpacity(0.55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _buildHeaderCard(),
            _buildRulesCard(),
            _buildDeleteAccountSection(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _deleteConfirmController.dispose();
    super.dispose();
  }
}