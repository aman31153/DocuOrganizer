import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudinaryService {
  // Updated with user credentials
  static const String cloudName = "tcs1bhu2";
  static const String uploadPreset = "documents"; // Using the unsigned preset created by the user

  Future<String?> uploadFile(File file) async {
    // Using 'auto' instead of 'raw' to handle images, pdfs, and other docs automatically
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/auto/upload');
    
    try {
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send().timeout(const Duration(seconds: 30));
      final responseData = await response.stream.toBytes();
      final responseString = utf8.decode(responseData);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonMap = jsonDecode(responseString);
        return jsonMap['secure_url'];
      } else {
        debugPrint('Cloudinary Error Response: $responseString');
        throw Exception('Cloudinary upload failed with status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Cloudinary Upload Exception: $e');
      rethrow;
    }
  }
}
