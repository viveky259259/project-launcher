import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:launcher_models/launcher_models.dart';

/// Parse a date field that may be either an RFC3339 string or a BSON extended
/// JSON object like {"$date": {"$numberLong": "1234567890"}} or {"$date": "..."}.
DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  if (raw is String) return DateTime.tryParse(raw);
  if (raw is Map) {
    final dateVal = raw['\$date'];
    if (dateVal is String) return DateTime.tryParse(dateVal);
    if (dateVal is Map) {
      final ms = dateVal['\$numberLong'];
      if (ms != null) {
        return DateTime.fromMillisecondsSinceEpoch(int.parse(ms.toString()));
      }
    }
    if (dateVal is int) {
      return DateTime.fromMillisecondsSinceEpoch(dateVal);
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// MemberActivity model
// ---------------------------------------------------------------------------

class MemberActivity {
  final String githubLogin;
  final String? avatarUrl;
  final String role;
  final int syncedRepos;
  final int totalRepos;
  final DateTime? lastSeenAt;
  final bool isDrifted;
  final DateTime joinedAt;

  const MemberActivity({
    required this.githubLogin,
    this.avatarUrl,
    required this.role,
    required this.syncedRepos,
    required this.totalRepos,
    this.lastSeenAt,
    required this.isDrifted,
    required this.joinedAt,
  });

  int get missingCount => totalRepos - syncedRepos;
  double get syncProgress => totalRepos > 0 ? syncedRepos / totalRepos : 0.0;

  factory MemberActivity.fromJson(Map<String, dynamic> json) {
    return MemberActivity(
      githubLogin: json['githubLogin'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      role: json['role'] as String? ?? 'developer',
      syncedRepos: json['syncedRepos'] as int? ?? 0,
      totalRepos: json['totalRepos'] as int? ?? 0,
      lastSeenAt: _parseDate(json['lastSeenAt']),
      isDrifted: json['isDrifted'] as bool? ?? false,
      joinedAt: _parseDate(json['joinedAt']) ?? DateTime.now(),
    );
  }
}

// ---------------------------------------------------------------------------
// ApiKeyInfo model
// ---------------------------------------------------------------------------

class ApiKeyInfo {
  final String key;
  final String? memberLogin;
  final String role;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final bool revoked;

  const ApiKeyInfo({
    required this.key,
    this.memberLogin,
    required this.role,
    required this.createdAt,
    this.lastUsedAt,
    required this.revoked,
  });

  factory ApiKeyInfo.fromJson(Map<String, dynamic> json) {
    return ApiKeyInfo(
      key: json['key'] as String,
      memberLogin: json['memberLogin'] as String?,
      role: json['role'] as String? ?? 'developer',
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      lastUsedAt: _parseDate(json['lastUsedAt']),
      revoked: json['revoked'] as bool? ?? false,
    );
  }
}

// ---------------------------------------------------------------------------
// InviteResult model
// ---------------------------------------------------------------------------

class InviteResult {
  final String memberLogin;
  final String apiKey; // full key, shown once

  const InviteResult({required this.memberLogin, required this.apiKey});

  factory InviteResult.fromJson(Map<String, dynamic> json) {
    return InviteResult(
      memberLogin: json['member'] as String,
      apiKey: json['apiKey'] as String,
    );
  }
}

// ---------------------------------------------------------------------------
// AdminApiException
// ---------------------------------------------------------------------------

class AdminApiException implements Exception {
  final int? statusCode;
  final String message;

  const AdminApiException(this.message, {this.statusCode});

  @override
  String toString() => statusCode != null
      ? 'AdminApiException($statusCode): $message'
      : 'AdminApiException: $message';
}

// ---------------------------------------------------------------------------
// AdminApi
// ---------------------------------------------------------------------------

class AdminApi {
  static String? _serverUrl;
  static String? _token;
  static String? _orgSlug;

  static void configure(String serverUrl, String token, String orgSlug) {
    _serverUrl = serverUrl.endsWith('/') ? serverUrl.substring(0, serverUrl.length - 1) : serverUrl;
    _token = token;
    _orgSlug = orgSlug;
  }

  static bool get isConfigured => _serverUrl != null && _token != null && _orgSlug != null;

  static String get serverUrl => _serverUrl ?? '';
  static String get orgSlug => _orgSlug ?? '';

  static String get _orgBase => '/api/orgs/$_orgSlug/admin';

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Uri _uri(String path) => Uri.parse('$_serverUrl$path');

  static Future<dynamic> _get(String path) async {
    final response = await http.get(_uri(path), headers: _headers);
    return _decode(response);
  }

  static Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final response = await http.put(
      _uri(path),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      _uri(path),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  static Future<dynamic> _patch(String path, Map<String, dynamic> body) async {
    final response = await http.patch(
      _uri(path),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  static Future<dynamic> _delete(String path) async {
    final response = await http.delete(_uri(path), headers: _headers);
    return _decode(response);
  }

  static dynamic _decode(http.Response response) {
    if (response.statusCode == 204) return null;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    String message;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      message = body['error'] as String? ?? body['message'] as String? ?? response.body;
    } catch (_) {
      message = response.body.isEmpty ? 'HTTP ${response.statusCode}' : response.body;
    }
    throw AdminApiException(message, statusCode: response.statusCode);
  }

  // ---------------------------------------------------------------------------
  // Catalog CRUD
  // ---------------------------------------------------------------------------

  static Future<Catalog> getCatalog() async {
    final json = await _get('$_orgBase/catalog') as Map<String, dynamic>;
    return Catalog.fromJson(json);
  }

  static Future<void> updateCatalog(Catalog catalog) async {
    await _put('$_orgBase/catalog', catalog.toJson());
  }

  static Future<void> publishCatalog(Catalog catalog) async {
    await _post('$_orgBase/catalog/publish', catalog.toJson());
  }

  // ---------------------------------------------------------------------------
  // Members
  // ---------------------------------------------------------------------------

  static Future<List<MemberActivity>> getMembers() async {
    final json = await _get('$_orgBase/members') as List<dynamic>;
    return json
        .cast<Map<String, dynamic>>()
        .map(MemberActivity.fromJson)
        .toList();
  }

  static Future<InviteResult> inviteMember(String githubLogin, String role) async {
    final json = await _post('$_orgBase/members/invite', {
      'githubLogin': githubLogin,
      'role': role,
    }) as Map<String, dynamic>;
    return InviteResult.fromJson(json);
  }

  // ---------------------------------------------------------------------------
  // API Key management
  // ---------------------------------------------------------------------------

  static Future<List<ApiKeyInfo>> listMemberKeys(String login) async {
    final json = await _get('$_orgBase/members/$login/keys') as List<dynamic>;
    return json
        .cast<Map<String, dynamic>>()
        .map(ApiKeyInfo.fromJson)
        .toList();
  }

  static Future<String> generateMemberKey(String login) async {
    final json = await _post('$_orgBase/members/$login/keys', {})
        as Map<String, dynamic>;
    return json['apiKey'] as String;
  }

  static Future<void> revokeMemberKey(String login, String key) async {
    await _delete('$_orgBase/members/$login/keys/$key');
  }

  static Future<void> updateMemberRole(String login, String role) async {
    await _patch('$_orgBase/members/$login', {'role': role});
  }

  static Future<void> removeMember(String login) async {
    await _delete('$_orgBase/members/$login');
  }

  // ---------------------------------------------------------------------------
  // Templates
  // ---------------------------------------------------------------------------

  static Future<List<dynamic>> getTemplates() async {
    final json = await _get('$_orgBase/templates') as List<dynamic>;
    return json;
  }

  static Future<void> createTemplate(Map<String, dynamic> template) async {
    await _post('$_orgBase/templates', template);
  }

  static Future<void> updateTemplate(String name, Map<String, dynamic> template) async {
    await _put('$_orgBase/templates/$name', template);
  }

  static Future<void> deleteTemplate(String name) async {
    await _delete('$_orgBase/templates/$name');
  }
}
