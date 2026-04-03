import 'dart:convert';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class OrgSummary {
  final String slug;
  final String name;
  final String plan;
  final int seats;
  final int memberCount;
  final bool suspended;
  final DateTime createdAt;

  const OrgSummary({
    required this.slug,
    required this.name,
    required this.plan,
    required this.seats,
    required this.memberCount,
    required this.suspended,
    required this.createdAt,
  });

  factory OrgSummary.fromJson(Map<String, dynamic> json) {
    return OrgSummary(
      slug: json['slug'] as String,
      name: json['name'] as String,
      plan: json['plan'] as String,
      seats: json['seats'] as int? ?? 0,
      memberCount: json['memberCount'] as int? ?? 0,
      suspended: json['suspended'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'name': name,
        'plan': plan,
        'seats': seats,
        'memberCount': memberCount,
        'suspended': suspended,
        'createdAt': createdAt.toIso8601String(),
      };
}

class OrgDetail extends OrgSummary {
  final String githubOrg;
  final List<String> allowedTeams;
  final Map<String, bool> featureFlags;
  final List<OrgMember> members;

  const OrgDetail({
    required super.slug,
    required super.name,
    required super.plan,
    required super.seats,
    required super.memberCount,
    required super.suspended,
    required super.createdAt,
    required this.githubOrg,
    required this.allowedTeams,
    required this.featureFlags,
    required this.members,
  });

  factory OrgDetail.fromJson(Map<String, dynamic> json) {
    return OrgDetail(
      slug: json['slug'] as String,
      name: json['name'] as String,
      plan: json['plan'] as String,
      seats: json['seats'] as int? ?? 0,
      memberCount: json['memberCount'] as int? ?? 0,
      suspended: json['suspended'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      githubOrg: json['githubOrg'] as String? ?? '',
      allowedTeams: (json['allowedTeams'] as List<dynamic>?)
              ?.cast<String>()
              .toList() ??
          [],
      featureFlags: (json['featureFlags'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as bool)) ??
          {},
      members: (json['members'] as List<dynamic>?)
              ?.map((m) => OrgMember.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'githubOrg': githubOrg,
        'allowedTeams': allowedTeams,
        'featureFlags': featureFlags,
        'members': members.map((m) => m.toJson()).toList(),
      };
}

class OrgMember {
  final String githubLogin;
  final String? avatarUrl;
  final String role;
  final DateTime joinedAt;
  final DateTime? lastSeenAt;

  const OrgMember({
    required this.githubLogin,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
    this.lastSeenAt,
  });

  factory OrgMember.fromJson(Map<String, dynamic> json) {
    return OrgMember(
      githubLogin: json['githubLogin'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      role: json['role'] as String? ?? 'member',
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      lastSeenAt: json['lastSeenAt'] != null
          ? DateTime.tryParse(json['lastSeenAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'githubLogin': githubLogin,
        'avatarUrl': avatarUrl,
        'role': role,
        'joinedAt': joinedAt.toIso8601String(),
        'lastSeenAt': lastSeenAt?.toIso8601String(),
      };
}

class LicenseKeyInfo {
  final String key;
  final String orgSlug;
  final int seats;
  final String plan;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? lastValidatedAt;
  final bool revoked;

  const LicenseKeyInfo({
    required this.key,
    required this.orgSlug,
    required this.seats,
    required this.plan,
    required this.createdAt,
    this.expiresAt,
    this.lastValidatedAt,
    required this.revoked,
  });

  factory LicenseKeyInfo.fromJson(Map<String, dynamic> json) {
    return LicenseKeyInfo(
      key: json['key'] as String,
      orgSlug: json['orgSlug'] as String,
      seats: json['seats'] as int? ?? 0,
      plan: json['plan'] as String? ?? 'starter',
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      lastValidatedAt: json['lastValidatedAt'] != null
          ? DateTime.tryParse(json['lastValidatedAt'] as String)
          : null,
      revoked: json['revoked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'orgSlug': orgSlug,
        'seats': seats,
        'plan': plan,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'lastValidatedAt': lastValidatedAt?.toIso8601String(),
        'revoked': revoked,
      };
}

class PlatformMetrics {
  final int totalOrgs;
  final int activeOrgs;
  final int totalMembers;
  final int totalRepos;
  final Map<String, int> orgsByPlan;

  const PlatformMetrics({
    required this.totalOrgs,
    required this.activeOrgs,
    required this.totalMembers,
    required this.totalRepos,
    required this.orgsByPlan,
  });

  factory PlatformMetrics.fromJson(Map<String, dynamic> json) {
    return PlatformMetrics(
      totalOrgs: json['totalOrgs'] as int? ?? 0,
      activeOrgs: json['activeOrgs'] as int? ?? 0,
      totalMembers: json['totalMembers'] as int? ?? 0,
      totalRepos: json['totalRepos'] as int? ?? 0,
      orgsByPlan: (json['orgsByPlan'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ??
          {},
    );
  }

  Map<String, dynamic> toJson() => {
        'totalOrgs': totalOrgs,
        'activeOrgs': activeOrgs,
        'totalMembers': totalMembers,
        'totalRepos': totalRepos,
        'orgsByPlan': orgsByPlan,
      };
}

class CreateOrgRequest {
  final String slug;
  final String name;
  final String plan;
  final int seats;
  final String githubOrg;

  const CreateOrgRequest({
    required this.slug,
    required this.name,
    required this.plan,
    required this.seats,
    required this.githubOrg,
  });

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'name': name,
        'plan': plan,
        'seats': seats,
        'githubOrg': githubOrg,
      };
}

class UpdateOrgRequest {
  final String? plan;
  final int? seats;
  final Map<String, bool>? featureFlags;

  const UpdateOrgRequest({
    this.plan,
    this.seats,
    this.featureFlags,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (plan != null) json['plan'] = plan;
    if (seats != null) json['seats'] = seats;
    if (featureFlags != null) json['featureFlags'] = featureFlags;
    return json;
  }
}

// ---------------------------------------------------------------------------
// SuperAdminApiException
// ---------------------------------------------------------------------------

class SuperAdminApiException implements Exception {
  final int? statusCode;
  final String message;

  const SuperAdminApiException(this.message, {this.statusCode});

  @override
  String toString() => statusCode != null
      ? 'SuperAdminApiException($statusCode): $message'
      : 'SuperAdminApiException: $message';
}

// ---------------------------------------------------------------------------
// SuperAdminApi
// ---------------------------------------------------------------------------

class SuperAdminApi {
  static String? _serverUrl;
  static String? _token;

  static void configure(String serverUrl, String token) {
    _serverUrl = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    _token = token;
  }

  static bool get isConfigured => _serverUrl != null && _token != null;

  static String get serverUrl => _serverUrl ?? '';

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Uri _uri(String path) => Uri.parse('$_serverUrl$path');

  static Future<dynamic> _get(String path) async {
    final response = await http.get(_uri(path), headers: _headers);
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

  static Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final response = await http.put(
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
      message = body['error'] as String? ??
          body['message'] as String? ??
          response.body;
    } catch (_) {
      message = response.body.isEmpty
          ? 'HTTP ${response.statusCode}'
          : response.body;
    }
    throw SuperAdminApiException(message, statusCode: response.statusCode);
  }

  // ---------------------------------------------------------------------------
  // Orgs
  // ---------------------------------------------------------------------------

  static Future<List<OrgSummary>> listOrgs() async {
    final json = await _get('/api/super-admin/orgs') as List<dynamic>;
    return json
        .cast<Map<String, dynamic>>()
        .map(OrgSummary.fromJson)
        .toList();
  }

  static Future<OrgSummary> createOrg(CreateOrgRequest req) async {
    final json = await _post('/api/super-admin/orgs', req.toJson())
        as Map<String, dynamic>;
    return OrgSummary.fromJson(json);
  }

  static Future<OrgDetail> getOrg(String slug) async {
    final json = await _get('/api/super-admin/orgs/$slug')
        as Map<String, dynamic>;
    return OrgDetail.fromJson(json);
  }

  static Future<void> updateOrg(String slug, UpdateOrgRequest req) async {
    await _put('/api/super-admin/orgs/$slug', req.toJson());
  }

  static Future<void> suspendOrg(String slug) async {
    await _post('/api/super-admin/orgs/$slug/suspend', {});
  }

  static Future<void> unsuspendOrg(String slug) async {
    await _post('/api/super-admin/orgs/$slug/unsuspend', {});
  }

  // ---------------------------------------------------------------------------
  // Members
  // ---------------------------------------------------------------------------

  static Future<List<OrgMember>> listOrgMembers(String slug) async {
    final json =
        await _get('/api/super-admin/orgs/$slug/members') as List<dynamic>;
    return json
        .cast<Map<String, dynamic>>()
        .map(OrgMember.fromJson)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // License Keys
  // ---------------------------------------------------------------------------

  static Future<List<LicenseKeyInfo>> listLicenseKeys() async {
    final json =
        await _get('/api/super-admin/license-keys') as List<dynamic>;
    return json
        .cast<Map<String, dynamic>>()
        .map(LicenseKeyInfo.fromJson)
        .toList();
  }

  static Future<LicenseKeyInfo> generateKey(String orgSlug, int seats) async {
    final json = await _post('/api/super-admin/license-keys', {
      'orgSlug': orgSlug,
      'seats': seats,
    }) as Map<String, dynamic>;
    return LicenseKeyInfo.fromJson(json);
  }

  static Future<void> revokeKey(String key) async {
    await _delete('/api/super-admin/license-keys/$key');
  }

  // ---------------------------------------------------------------------------
  // Metrics
  // ---------------------------------------------------------------------------

  static Future<PlatformMetrics> getMetrics() async {
    final json = await _get('/api/super-admin/metrics')
        as Map<String, dynamic>;
    return PlatformMetrics.fromJson(json);
  }
}
