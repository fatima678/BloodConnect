import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class CloudinaryUploadService {
  CloudinaryUploadService._();

  static const String cloudName = 'dckvdiawp';

  static const String uploadPreset = 'blood_connect_profiles';

  static Future<String> uploadProfileImage({
    required File imageFile,
    required String uid,
  }) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri);

    request.fields['upload_preset'] = uploadPreset;
    request.fields['folder'] = 'blood_connect/patient_profiles/$uid';

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
      ),
    );

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    Map<String, dynamic> data = {};

    try {
      data = jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (_) {
      data = {};
    }

    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300) {
      final message = data['error'] is Map
          ? data['error']['message']?.toString()
          : null;

      throw Exception(
        message ?? 'Cloudinary image upload failed.',
      );
    }

    final secureUrl = data['secure_url']?.toString();

    if (secureUrl == null || secureUrl.trim().isEmpty) {
      throw Exception('Cloudinary image URL not found.');
    }

    return secureUrl;
  }
}