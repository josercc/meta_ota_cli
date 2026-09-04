import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class MetaOtaClient {
  MetaOtaClient({required this.api, required this.token});

  final String api;
  final String token;

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        'authorization': 'Bearer $token',
      };

  Future<String> get(String path) async {
    final res = await http.get(Uri.parse('$api$path'), headers: _headers);
    _ensure(res);
    return _pretty(res.body);
  }

  Future<String> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$api$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    _ensure(res);
    return _pretty(res.body);
  }

  /// POST without auth (device check API).
  Future<String> postPublic(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$api$path'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    );
    _ensure(res);
    return res.body;
  }

  /// Returns raw JSON map from a successful POST.
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await http.post(
      Uri.parse('$api$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    _ensure(res);
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  }

  String _pretty(String body) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(body));
    } catch (_) {
      return body;
    }
  }

  void _ensure(http.Response res) {
    if (res.statusCode >= 400) {
      stderr.writeln('HTTP ${res.statusCode}: ${res.body}');
      exit(1);
    }
  }
}

void requireToken(String token) {
  if (token.trim().isEmpty) {
    stderr.writeln(
      'Missing admin token. Set META_OTA_TOKEN, pass --token, run '
      '`meta_ota config --token ...`, or start the API so storage/.admin_token exists.',
    );
    exit(64);
  }
}
