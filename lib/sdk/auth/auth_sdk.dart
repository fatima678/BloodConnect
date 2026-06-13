// lib/sdk/auth/auth_sdk.dart

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/firebase_collections.dart';
import '../core/sdk_exception.dart';
import '../models/app_user_model.dart';

class AuthSdk {
  AuthSdk._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const List<String> userRoles = [
    'patient',
    'donor',
    'team_volunteer',
  ];

  static const List<String> bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  static String normalizeRole(String role) {
    final value = role.trim().toLowerCase();

    if (value == 'volunteer') {
      return 'team_volunteer';
    }

    return value;
  }

  static String normalizePhone(String phone) {
    return phone.trim().replaceAll(' ', '').replaceAll('-', '');
  }

  static String? normalizeBloodGroup(String? bloodGroup) {
    if (bloodGroup == null) return null;

    final value = bloodGroup.trim().toUpperCase().replaceAll(' ', '');

    if (bloodGroups.contains(value)) {
      return value;
    }

    return null;
  }

  static bool _isValidEmail(String email) {
    return RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    ).hasMatch(email.trim());
  }

  static bool _isValidPakistaniPhone(String phone) {
    final value = normalizePhone(phone);
    return RegExp(r'^(03[0-9]{9}|\+923[0-9]{9})$').hasMatch(value);
  }

  static CollectionReference<Map<String, dynamic>> _roleCollection(
    String role,
  ) {
    final cleanRole = normalizeRole(role);
    final collectionName = FirebaseCollections.roleCollection(cleanRole);

    return _firestore
        .collection(FirebaseCollections.users)
        .doc(FirebaseCollections.rolesDoc)
        .collection(collectionName);
  }

  static DocumentReference<Map<String, dynamic>> _roleUserDoc({
    required String role,
    required String uid,
  }) {
    return _roleCollection(role).doc(uid);
  }

  static Future<void> _cacheUser(AppUserModel user) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('user_uid', user.uid);
    await prefs.setString('uid', user.uid);
    await prefs.setString('user_role', user.role);
    await prefs.setString('role', user.role);
    await prefs.setString('user_email', user.email);
    await prefs.setString('user_name', user.name);
    await prefs.setString('user_data', jsonEncode(user.toMap()));
  }

  static Future<void> clearCachedUser() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('user_uid');
    await prefs.remove('uid');
    await prefs.remove('user_role');
    await prefs.remove('role');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    await prefs.remove('user_data');

    // Old Laravel/API token keys clear.
    await prefs.remove('auth_token');
    await prefs.remove('volunteer_auth_token');
    await prefs.remove('token');
    await prefs.remove('idToken');
    await prefs.remove('id_token');
    await prefs.remove('firebase_token');
    await prefs.remove('firebase_id_token');
    await prefs.remove('access_token');
    await prefs.remove('bearer_token');
    await prefs.remove('refresh_token');

    // Active request cache clear.
    await prefs.remove('latest_active_blood_request_id');
  }

  static Future<AppUserModel> registerUser({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
    String? bloodGroup,
    String? fcmToken,
    String? deviceType,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = normalizePhone(phone);
    final cleanRole = normalizeRole(role);
    final cleanBloodGroup = normalizeBloodGroup(bloodGroup);

    if (cleanName.length < 2) {
      throw const SdkException('Full name must be at least 2 characters.');
    }

    if (!_isValidEmail(cleanEmail)) {
      throw const SdkException('Please enter a valid email address.');
    }

    if (!_isValidPakistaniPhone(cleanPhone)) {
      throw const SdkException(
        'Please enter a valid Pakistani phone number. Example: 03001234567 or +923001234567.',
      );
    }

    if (password.length < 6 || password.contains(' ')) {
      throw const SdkException(
        'Password must be at least 6 characters and should not contain spaces.',
      );
    }

    if (!userRoles.contains(cleanRole)) {
      throw const SdkException('Invalid user role.');
    }

    if (cleanRole == 'team_volunteer' && cleanBloodGroup == null) {
      throw const SdkException('Blood group is required for team volunteer.');
    }

    UserCredential credential;

    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw const SdkException('Email already exists.');
      }

      if (e.code == 'weak-password') {
        throw const SdkException('Password is too weak.');
      }

      if (e.code == 'invalid-email') {
        throw const SdkException('Please enter a valid email address.');
      }

      throw SdkException(e.message ?? 'Registration failed.');
    } catch (e) {
      throw SdkException('Registration failed: $e');
    }

    final firebaseUser = credential.user;

    if (firebaseUser == null) {
      throw const SdkException('Firebase user was not created.');
    }

    final uid = firebaseUser.uid;

    try {
      await firebaseUser.updateDisplayName(cleanName);

      final now = DateTime.now().toIso8601String();

      final userData = <String, dynamic>{
        'uid': uid,
        'name': cleanName,
        'email': cleanEmail,
        'phone': cleanPhone,
        'role': cleanRole,
        'status': 'active',
        'created_at': now,
        'updated_at': now,
      };

      if (cleanRole == 'team_volunteer') {
        userData['blood_group'] = cleanBloodGroup;
      }

      if (fcmToken != null && fcmToken.trim().isNotEmpty) {
        userData['fcm_token'] = fcmToken.trim();
        userData['device_type'] = deviceType;
        userData['fcm_token_updated_at'] = now;
      }

      await _roleUserDoc(role: cleanRole, uid: uid).set(userData);

      final appUser = AppUserModel.fromMap(userData);
      await _cacheUser(appUser);

      return appUser;
    } catch (e) {
      try {
        await firebaseUser.delete();
      } catch (_) {}

      throw SdkException('Failed to save user profile: $e');
    }
  }

  static Future<AppUserModel> login({
    required String email,
    required String password,
    required String expectedRole,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanRole = normalizeRole(expectedRole);

    if (!_isValidEmail(cleanEmail)) {
      throw const SdkException('Please enter a valid email address.');
    }

    if (password.trim().isEmpty) {
      throw const SdkException('Password is required.');
    }

    if (!userRoles.contains(cleanRole)) {
      throw const SdkException('Invalid user role.');
    }

    UserCredential credential;

    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
    } on FirebaseAuthException {
      throw const SdkException('Invalid email or password.');
    } catch (e) {
      throw SdkException('Login failed: $e');
    }

    final firebaseUser = credential.user;

    if (firebaseUser == null) {
      throw const SdkException('Login session not found.');
    }

    final snapshot = await _roleUserDoc(
      role: cleanRole,
      uid: firebaseUser.uid,
    ).get();

    if (!snapshot.exists || snapshot.data() == null) {
      await _auth.signOut();
      throw const SdkException('User profile not found for this role.');
    }

    final data = Map<String, dynamic>.from(snapshot.data()!);
    data['uid'] = data['uid'] ?? firebaseUser.uid;

    final appUser = AppUserModel.fromMap(data);

    if (normalizeRole(appUser.role) != cleanRole) {
      await _auth.signOut();
      throw const SdkException('Role mismatch.');
    }

    if (appUser.status.trim().toLowerCase() != 'active') {
      await _auth.signOut();
      throw const SdkException('Your account is not active.');
    }

    await _cacheUser(appUser);

    return appUser;
  }

  static Future<AppUserModel> saveFcmTokenForUser({
    required AppUserModel user,
    required String? fcmToken,
    String? deviceType,
  }) async {
    final token = fcmToken?.trim() ?? '';

    if (token.isEmpty) {
      return user;
    }

    final now = DateTime.now().toIso8601String();

    await _roleUserDoc(
      role: user.role,
      uid: user.uid,
    ).set(
      {
        'fcm_token': token,
        'device_type': deviceType,
        'fcm_token_updated_at': now,
        'updated_at': now,
      },
      SetOptions(merge: true),
    );

    final updatedMap = Map<String, dynamic>.from(user.toMap());

    updatedMap['fcm_token'] = token;
    updatedMap['device_type'] = deviceType;
    updatedMap['fcm_token_updated_at'] = now;
    updatedMap['updated_at'] = now;

    final updatedUser = AppUserModel.fromMap(updatedMap);
    await _cacheUser(updatedUser);

    return updatedUser;
  }

  static Future<AppUserModel?> currentAppUser({
    String? expectedRole,
  }) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      return null;
    }

    if (expectedRole != null && expectedRole.trim().isNotEmpty) {
      final cleanRole = normalizeRole(expectedRole);

      final snapshot = await _roleUserDoc(
        role: cleanRole,
        uid: firebaseUser.uid,
      ).get();

      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }

      final data = Map<String, dynamic>.from(snapshot.data()!);
      data['uid'] = data['uid'] ?? firebaseUser.uid;

      return AppUserModel.fromMap(data);
    }

    for (final role in userRoles) {
      final snapshot = await _roleUserDoc(
        role: role,
        uid: firebaseUser.uid,
      ).get();

      if (snapshot.exists && snapshot.data() != null) {
        final data = Map<String, dynamic>.from(snapshot.data()!);
        data['uid'] = data['uid'] ?? firebaseUser.uid;

        return AppUserModel.fromMap(data);
      }
    }

    return null;
  }

  static Future<void> logout() async {
    await clearCachedUser();
    await _auth.signOut();
  }

  static Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }
}