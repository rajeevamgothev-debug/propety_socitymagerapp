import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_storage_backend_base.dart';

AuthStorageBackend createAuthStorageBackend() => _FileAuthStorageBackend();

class _FileAuthStorageBackend implements AuthStorageBackend {
  static const String _fileName = 'urbaneasyflats_mobile_auth_storage.json';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  final Map<String, Object?> _values = <String, Object?>{};
  File? _storageFile;
  bool _isInitialized = false;

  @override
  Future<void> init() async {
    if (_isInitialized) {
      return;
    }

    _isInitialized = true;
    try {
      final Map<String, String> secureValues = await _secureStorage.readAll();
      if (secureValues.isNotEmpty) {
        _values
          ..clear()
          ..addAll(secureValues);
        return;
      }

      _storageFile = _resolveStorageFile();
      if (_storageFile == null || !await _storageFile!.exists()) {
        return;
      }
      final String raw = await _storageFile!.readAsString();
      if (raw.trim().isEmpty) {
        return;
      }

      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }

      _values
        ..clear()
        ..addAll(decoded.cast<String, Object?>());
      await _persist();
    } catch (_) {
      _values.clear();
    }
  }

  @override
  String? getString(String key) {
    final Object? value = _values[key];
    return value is String ? value : null;
  }

  @override
  int? getInt(String key) {
    final Object? value = _values[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
    await _persist();
  }

  @override
  Future<void> setInt(String key, int value) async {
    _values[key] = value;
    await _persist();
  }

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
    await _persist();
  }

  Future<void> _persist() async {
    try {
      await _secureStorage.deleteAll();
      for (final MapEntry<String, Object?> entry in _values.entries) {
        final Object? value = entry.value;
        if (value != null) {
          await _secureStorage.write(key: entry.key, value: value.toString());
        }
      }
    } catch (_) {
      // Keep the in-memory cache even if disk persistence is unavailable.
    }
  }

  File? _resolveStorageFile() {
    try {
      return File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}$_fileName',
      );
    } catch (_) {
      return null;
    }
  }
}
