import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_client.dart' show ApiResponse;
import 'api_config.dart';
import 'auth_storage.dart';

const String _uploadedImageBucketRoot =
    'https://urbaneasyflats.s3.ap-south-1.amazonaws.com/';
const String _uploadedImageBucketFolder = 'dev/';

String? _normalizeUploadedImageUrl(String? value) {
  final String text = value?.trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  if (text.startsWith('http://') || text.startsWith('https://')) {
    return text;
  }
  if (text.startsWith('//')) {
    return 'https:$text';
  }

  String path = text.replaceFirst(RegExp(r'^/+'), '');
  final String fileName = path.split('/').last;
  if (!fileName.contains('.') && !fileName.endsWith('_Original')) {
    path = '${path}_Original.png';
  }
  if (path.startsWith(_uploadedImageBucketFolder)) {
    return '$_uploadedImageBucketRoot$path';
  }
  return '$_uploadedImageBucketRoot$_uploadedImageBucketFolder$path';
}

bool _looksLikeUploadedImageStringKey(String key) {
  final String normalized = key.toLowerCase();
  return normalized.contains('url') ||
      normalized.contains('generation') ||
      normalized.contains('original') ||
      normalized.contains('image') ||
      normalized.contains('photo') ||
      normalized.contains('picture') ||
      normalized.contains('avatar');
}

bool _looksLikeUploadedImageContainerKey(String key) {
  final String normalized = key.toLowerCase();
  return normalized == 'data' ||
      normalized.contains('image') ||
      normalized.contains('photo') ||
      normalized.contains('picture') ||
      normalized.contains('avatar') ||
      normalized.contains('profile') ||
      normalized.contains('vendor') ||
      normalized.contains('tenant') ||
      normalized.contains('resident') ||
      normalized.contains('user');
}

String? _readUploadedImageUrl(dynamic value, {int depth = 0}) {
  if (value == null || depth > 8) {
    return null;
  }

  if (value is String) {
    return _normalizeUploadedImageUrl(value);
  }

  if (value is List) {
    for (final dynamic item in value) {
      final String? url = _readUploadedImageUrl(item, depth: depth + 1);
      if (url != null) {
        return url;
      }
    }
    return null;
  }

  if (value is Map) {
    for (final String key in <String>[
      'Image_Original_URL',
      'Image_URL',
      'Image_250_URL',
      'Image_500_URL',
      'Image_750_URL',
      'Image_Generation_Name',
      'Image_Original_Name',
      'Profile_Image_Original_URL',
      'Profile_Image_URL',
      'Profile_Image_Generation_Name',
      'Profile_Photo_URL',
      'Profile_Photo_Information',
      'Tenant_Profile_Image_Information',
      'Resident_Profile_Image_Information',
      'Vendor_Image_Information',
      'User_Profile_Image_Information',
      'Image_Information',
      'Image_Information_Data',
      'Image_Data',
      'Data',
    ]) {
      final dynamic raw = value[key];
      if (raw is String && !_looksLikeUploadedImageStringKey(key)) {
        continue;
      }
      final String? url = _readUploadedImageUrl(raw, depth: depth + 1);
      if (url != null) {
        return url;
      }
    }

    for (final MapEntry<dynamic, dynamic> entry in value.entries) {
      final String key = entry.key?.toString() ?? '';
      final dynamic raw = entry.value;
      String? url;
      if (raw is String) {
        if (_looksLikeUploadedImageStringKey(key)) {
          url = _normalizeUploadedImageUrl(raw);
        }
      } else if (_looksLikeUploadedImageContainerKey(key)) {
        url = _readUploadedImageUrl(raw, depth: depth + 1);
      }
      if (url != null) {
        return url;
      }
    }
  }

  return null;
}

class UploadService {
  UploadService._();

  static MediaType? _mediaTypeFromPath(String path) {
    final String ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'png' => MediaType('image', 'png'),
      'gif' => MediaType('image', 'gif'),
      'webp' => MediaType('image', 'webp'),
      'pdf' => MediaType('application', 'pdf'),
      'mp4' => MediaType('video', 'mp4'),
      'mp3' => MediaType('audio', 'mpeg'),
      _ => null,
    };
  }

  static Future<Map<String, dynamic>?> _uploadMultipart(
    File file, {
    required String endpoint,
    Map<String, String> fields = const <String, String>{},
    String fileField = 'file',
  }) async {
    final Uri url = Uri.parse('${ApiConfig.uploadBaseUrl}$endpoint');

    final http.MultipartRequest request = http.MultipartRequest('POST', url);

    request.fields.addAll(fields);
    final String? apiKey = AuthStorage.apiKey;
    final String? sessionId = AuthStorage.sessionId;
    final String? vendorId = AuthStorage.vendorId;

    if (apiKey != null && apiKey.isNotEmpty) {
      request.fields['ApiKey'] = apiKey;
      request.headers['ApiKey'] = apiKey;
    }
    if (sessionId != null && sessionId.isNotEmpty) {
      request.fields['SessionID'] = sessionId;
      request.headers['SessionID'] = sessionId;
    }
    if (vendorId != null && vendorId.isNotEmpty) {
      request.fields['VendorID'] = vendorId;
      request.headers['VendorID'] = vendorId;
    }

    final MediaType? contentType = _mediaTypeFromPath(file.path);
    final http.MultipartFile multipartFile = await http.MultipartFile.fromPath(
      fileField,
      file.path,
      contentType: contentType,
    );
    request.files.add(multipartFile);

    debugPrint(
      '[Upload] POST $url (file=${file.path}, size=${multipartFile.length} bytes, contentType=$contentType)',
    );

    final http.StreamedResponse streamedResponse = await request.send();
    final String responseBody = await streamedResponse.stream.bytesToString();

    debugPrint(
      '[Upload] status=${streamedResponse.statusCode} body=$responseBody',
    );

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(responseBody) as Map<String, dynamic>;
    } on FormatException {
      throw Exception('Upload failed (status ${streamedResponse.statusCode}).');
    }

    final bool success = json['success'] as bool? ?? false;
    if (!success) {
      final Map<String, dynamic> extras =
          (json['extras'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final String? message =
          extras['Message'] as String? ??
          extras['msg'] as String? ??
          extras['Status'] as String?;
      throw Exception(
        message ?? 'Upload failed (status ${streamedResponse.statusCode})',
      );
    }

    final Map<String, dynamic> extras =
        (json['extras'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return extras['Data'] as Map<String, dynamic>?;
  }

  static Future<String?> uploadImage(File file) async {
    final Map<String, dynamic>? data = await _uploadMultipart(
      file,
      endpoint: ApiConfig.uploadImage,
      fields: const <String, String>{'Image_Type': '1'},
      fileField: 'file',
    );
    final String? imageId = _readString(data, <String>['ImageID']);
    if (imageId == null && data != null) {
      throw Exception('Server did not return an image ID.');
    }
    return imageId;
  }

  static Future<String?> fetchImageInfo(String imageId) async {
    final ApiResponse response = await _postToUploadBase(
      ApiConfig.fetchImageInfo,
      <String, dynamic>{'ImageID': imageId},
    );

    if (response.success && response.data != null) {
      return _readUploadedImageUrl(response.data);
    }
    return null;
  }

  static Future<ApiResponse> removeImage(String imageId) async {
    return _postToUploadBase(ApiConfig.removeImage, <String, dynamic>{
      'ImageID': imageId,
    });
  }

  static Future<String?> uploadVideo(File file, {String? imageId}) async {
    final Map<String, String> fields = <String, String>{
      'Whether_Image_Available': (imageId != null && imageId.trim().isNotEmpty)
          .toString(),
      if (imageId != null && imageId.trim().isNotEmpty)
        'ImageID': imageId.trim(),
    };
    final Map<String, dynamic>? data = await _uploadMultipart(
      file,
      endpoint: ApiConfig.uploadVideo,
      fields: fields,
      fileField: 'file',
    );
    return _readString(data, <String>['VideoID']);
  }

  static Future<String?> fetchVideoInfo(String videoId) async {
    final ApiResponse response = await _postToUploadBase(
      ApiConfig.fetchVideoInfo,
      <String, dynamic>{'VideoID': videoId},
    );

    if (response.success && response.data != null) {
      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      return _readString(data, <String>['Video_Original_URL', 'Video_URL']);
    }
    return null;
  }

  static Future<ApiResponse> removeVideo(String videoId) async {
    return _postToUploadBase(ApiConfig.removeVideo, <String, dynamic>{
      'VideoID': videoId,
    });
  }

  static Future<String?> uploadAudio(File file) async {
    final Map<String, dynamic>? data = await _uploadMultipart(
      file,
      endpoint: ApiConfig.uploadAudio,
      fileField: 'file',
    );
    return _readString(data, <String>['AudioID']);
  }

  static Future<String?> fetchAudioInfo(String audioId) async {
    final ApiResponse response = await _postToUploadBase(
      ApiConfig.fetchAudioInfo,
      <String, dynamic>{'AudioID': audioId},
    );

    if (response.success && response.data != null) {
      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      return _readString(data, <String>['Audio_URL']);
    }
    return null;
  }

  static Future<ApiResponse> removeAudio(String audioId) async {
    return _postToUploadBase(ApiConfig.removeAudio, <String, dynamic>{
      'AudioID': audioId,
    });
  }

  static Future<String?> uploadDocument(File file) async {
    final Map<String, dynamic>? data = await _uploadMultipart(
      file,
      endpoint: ApiConfig.uploadDocument,
      fileField: 'file',
    );
    return _readString(data, <String>['DocumentID']);
  }

  static Future<String?> fetchDocumentInfo(String documentId) async {
    final ApiResponse response = await _postToUploadBase(
      ApiConfig.fetchDocumentInfo,
      <String, dynamic>{'DocumentID': documentId},
    );

    if (response.success && response.data != null) {
      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      return data['Document_URL'] as String?;
    }
    return null;
  }

  static Future<ApiResponse> removeDocument(String documentId) async {
    return _postToUploadBase(ApiConfig.removeDocument, <String, dynamic>{
      'DocumentID': documentId,
    });
  }

  static Future<ApiResponse> _postToUploadBase(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final Map<String, dynamic> requestBody = <String, dynamic>{...body};

    final String? apiKey = AuthStorage.apiKey;
    final String? sessionId = AuthStorage.sessionId;
    final String? vendorId = AuthStorage.vendorId;

    if (apiKey != null && apiKey.isNotEmpty) {
      requestBody['ApiKey'] = apiKey;
    }
    if (sessionId != null && sessionId.isNotEmpty) {
      requestBody['SessionID'] = sessionId;
    }
    if (vendorId != null && vendorId.isNotEmpty) {
      requestBody['VendorID'] = vendorId;
    }

    final Uri url = Uri.parse('${ApiConfig.uploadBaseUrl}$endpoint');
    final http.Response response = await http.post(
      url,
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    return ApiResponse(
      success: json['success'] as bool? ?? false,
      extras: (json['extras'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    );
  }

  static String? _readString(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) {
      return null;
    }

    for (final String key in keys) {
      final String? value = data[key] as String?;
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}
