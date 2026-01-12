import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

class PulseApi {
  PulseApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String _extractErrorMessage(http.Response res) {
    final body = res.body;
    if (body.isEmpty) return 'HTTP ${res.statusCode}';

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is String && error.trim().isNotEmpty) return error;
        if (error != null) return error.toString();

        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) return message;
      }
      if (decoded is String && decoded.trim().isNotEmpty) return decoded;
    } catch (_) {
      // ignore json parse
    }

    return body.trim().isNotEmpty ? body.trim() : 'HTTP ${res.statusCode}';
  }

  Future<List<Map<String, dynamic>>> listTips({String? userAddress}) async {
    final uri = Uri.parse(
      '$apiBaseUrl/v1/tips${userAddress == null ? '' : '/$userAddress'}',
    );
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception(
        'Failed to fetch tips (${res.statusCode}): ${_extractErrorMessage(res)}',
      );
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! List) {
      throw const FormatException('Expected list response');
    }

    return decoded
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> runScoutOnce() async {
    final uri = Uri.parse('$apiBaseUrl/v1/demo/run-scout-once');
    final res = await _client.post(uri);
    if (res.statusCode != 200) {
      throw Exception(
        'Scout failed (${res.statusCode}): ${_extractErrorMessage(res)}',
      );
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected object response');
    }

    return decoded;
  }

  Future<Map<String, dynamic>> getStatus() async {
    final uri = Uri.parse('$apiBaseUrl/v1/status');
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception(
        'Status failed (${res.statusCode}): ${_extractErrorMessage(res)}',
      );
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected object response');
    }

    return decoded;
  }

  Future<Map<String, dynamic>> payQris({
    required String merchantAddress,
    required int amountIdr,
    int? rateIdrPerMnee,
    bool isDemo = false,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/v1/payments/qris');
    final res = await _client.post(
      uri,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'merchantAddress': merchantAddress,
        'amountIDR': amountIdr,
        'rateIDRPerMNEE': rateIdrPerMnee ?? demoRateIdrPerMnee,
        'isDemo': isDemo,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception(
        'Payment failed (${res.statusCode}): ${_extractErrorMessage(res)}',
      );
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected object response');
    }

    return decoded;
  }

  Future<Map<String, dynamic>> getDemoQris() async {
    final uri = Uri.parse('$apiBaseUrl/v1/demo/qris');
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception(
        'Demo QR failed (${res.statusCode}): ${_extractErrorMessage(res)}',
      );
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected object response');
    }

    return decoded;
  }
}
