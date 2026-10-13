import 'dart:convert';

import 'package:betterhome/data/models.dart';
import 'package:http/http.dart' as http;

/// Households API surface (OpenAPI paths under households-service).
abstract class HouseholdsRepository {
  Future<UserProfile> syncMe({
    required String email,
    String? givenName,
    String? familyName,
    String language = 'en',
    String timezone = 'UTC',
  });

  Future<UserProfile> getMe();

  Future<List<Household>> listHouseholds();

  Future<Household> createHousehold({
    required String name,
    required String timezone,
  });

  Future<Household> getHousehold(String householdId);

  Future<List<Membership>> listMembers(String householdId);

  Future<Invitation> createInvitation({
    required String householdId,
    required String email,
    MembershipRole role = MembershipRole.member,
  });

  Future<Membership> acceptInvitation(String token);

  Future<Membership> setAway(String householdId, String userId);

  Future<Membership> clearAway(String householdId, String userId);

  Future<void> leave(String householdId);
}

class HttpHouseholdsRepository implements HouseholdsRepository {
  HttpHouseholdsRepository({
    required this.baseUrl,
    required this.accessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String accessToken;
  final http.Client _client;

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> _json(http.Response response) async {
    if (response.statusCode >= 400) {
      throw ApiException(
        response.body.isEmpty ? 'HTTP ${response.statusCode}' : response.body,
        statusCode: response.statusCode,
      );
    }
    if (response.body.isEmpty) {
      return {};
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> _jsonList(http.Response response) async {
    if (response.statusCode >= 400) {
      throw ApiException(
        response.body.isEmpty ? 'HTTP ${response.statusCode}' : response.body,
        statusCode: response.statusCode,
      );
    }
    return jsonDecode(response.body) as List<dynamic>;
  }

  @override
  Future<UserProfile> syncMe({
    required String email,
    String? givenName,
    String? familyName,
    String language = 'en',
    String timezone = 'UTC',
  }) async {
    final response = await _client.put(
      _uri('/v1/me'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'givenName': givenName,
        'familyName': familyName,
        'language': language,
        'timezone': timezone,
      }),
    );
    return UserProfile.fromJson(await _json(response));
  }

  @override
  Future<UserProfile> getMe() async {
    final response = await _client.get(_uri('/v1/me'), headers: _headers);
    return UserProfile.fromJson(await _json(response));
  }

  @override
  Future<List<Household>> listHouseholds() async {
    final response = await _client.get(
      _uri('/v1/households'),
      headers: _headers,
    );
    final list = await _jsonList(response);
    return list
        .map((e) => Household.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Household> createHousehold({
    required String name,
    required String timezone,
  }) async {
    final response = await _client.post(
      _uri('/v1/households'),
      headers: _headers,
      body: jsonEncode({'name': name, 'timezone': timezone}),
    );
    return Household.fromJson(await _json(response));
  }

  @override
  Future<Household> getHousehold(String householdId) async {
    final response = await _client.get(
      _uri('/v1/households/$householdId'),
      headers: _headers,
    );
    return Household.fromJson(await _json(response));
  }

  @override
  Future<List<Membership>> listMembers(String householdId) async {
    final response = await _client.get(
      _uri('/v1/households/$householdId/members'),
      headers: _headers,
    );
    final list = await _jsonList(response);
    return list
        .map((e) => Membership.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Invitation> createInvitation({
    required String householdId,
    required String email,
    MembershipRole role = MembershipRole.member,
  }) async {
    final response = await _client.post(
      _uri('/v1/households/$householdId/invitations'),
      headers: _headers,
      body: jsonEncode({'email': email, 'role': role.name}),
    );
    return Invitation.fromJson(await _json(response));
  }

  @override
  Future<Membership> acceptInvitation(String token) async {
    final response = await _client.post(
      _uri('/v1/invitations/$token/accept'),
      headers: _headers,
    );
    return Membership.fromJson(await _json(response));
  }

  @override
  Future<Membership> setAway(String householdId, String userId) async {
    final response = await _client.post(
      _uri('/v1/households/$householdId/members/$userId/away'),
      headers: _headers,
      body: '{}',
    );
    return Membership.fromJson(await _json(response));
  }

  @override
  Future<Membership> clearAway(String householdId, String userId) async {
    final response = await _client.delete(
      _uri('/v1/households/$householdId/members/$userId/away'),
      headers: _headers,
    );
    return Membership.fromJson(await _json(response));
  }

  @override
  Future<void> leave(String householdId) async {
    final response = await _client.post(
      _uri('/v1/households/$householdId/members/me/leave'),
      headers: _headers,
    );
    if (response.statusCode >= 400) {
      throw ApiException(response.body, statusCode: response.statusCode);
    }
  }
}

/// In-memory repository for widget tests and offline demo mode.
class FakeHouseholdsRepository implements HouseholdsRepository {
  FakeHouseholdsRepository({
    this.userId = 'user-1',
    this.authSubject = '11111111-1111-1111-1111-111111111111',
  });

  final String userId;
  final String authSubject;

  UserProfile? _me;
  final List<Household> _households = [];
  final Map<String, List<Membership>> _members = {};
  final Map<String, Invitation> _invitesByToken = {};

  @override
  Future<UserProfile> syncMe({
    required String email,
    String? givenName,
    String? familyName,
    String language = 'en',
    String timezone = 'UTC',
  }) async {
    _me = UserProfile(
      id: userId,
      authSubject: authSubject,
      email: email.toLowerCase(),
      givenName: givenName ?? '',
      familyName: familyName ?? '',
      language: language,
      timezone: timezone,
    );
    return _me!;
  }

  @override
  Future<UserProfile> getMe() async {
    final me = _me;
    if (me == null) {
      throw ApiException('not synced', statusCode: 404);
    }
    return me;
  }

  @override
  Future<List<Household>> listHouseholds() async =>
      List.unmodifiable(_households);

  @override
  Future<Household> createHousehold({
    required String name,
    required String timezone,
  }) async {
    final household = Household(
      id: 'hh-${_households.length + 1}',
      name: name,
      timezone: timezone,
      reminderDaysBefore: 0,
      reminderTime: '08:00:00',
      createdBy: userId,
    );
    _households.add(household);
    _members[household.id] = [
      Membership(
        id: 'm-${household.id}',
        userId: userId,
        householdId: household.id,
        role: MembershipRole.admin,
        joinedAt: DateTime.utc(2026, 1, 1),
      ),
    ];
    return household;
  }

  @override
  Future<Household> getHousehold(String householdId) async {
    return _households.firstWhere(
      (h) => h.id == householdId,
      orElse: () => throw ApiException('not found', statusCode: 404),
    );
  }

  @override
  Future<List<Membership>> listMembers(String householdId) async {
    return List.unmodifiable(_members[householdId] ?? const []);
  }

  @override
  Future<Invitation> createInvitation({
    required String householdId,
    required String email,
    MembershipRole role = MembershipRole.member,
  }) async {
    final invitation = Invitation(
      id: 'inv-${_invitesByToken.length + 1}',
      householdId: householdId,
      email: email.toLowerCase(),
      role: role,
      token: 'token-${_invitesByToken.length + 1}',
      expiresAt: DateTime.utc(2026, 12, 31),
    );
    _invitesByToken[invitation.token] = invitation;
    return invitation;
  }

  @override
  Future<Membership> acceptInvitation(String token) async {
    final invitation = _invitesByToken[token];
    if (invitation == null) {
      throw ApiException('not found', statusCode: 404);
    }
    final membership = Membership(
      id: 'm-accepted-$token',
      userId: userId,
      householdId: invitation.householdId,
      role: invitation.role,
      joinedAt: DateTime.utc(2026, 2, 1),
    );
    _members.putIfAbsent(invitation.householdId, () => []).add(membership);
    return membership;
  }

  @override
  Future<Membership> setAway(String householdId, String targetUserId) async {
    final list = _members[householdId] ?? [];
    final index = list.indexWhere((m) => m.userId == targetUserId);
    if (index < 0) {
      throw ApiException('not found', statusCode: 404);
    }
    final current = list[index];
    final updated = Membership(
      id: current.id,
      userId: current.userId,
      householdId: current.householdId,
      role: current.role,
      joinedAt: current.joinedAt,
      awayFrom: DateTime.utc(2026, 3, 1),
      awaySetBy: userId,
    );
    list[index] = updated;
    return updated;
  }

  @override
  Future<Membership> clearAway(String householdId, String targetUserId) async {
    final list = _members[householdId] ?? [];
    final index = list.indexWhere((m) => m.userId == targetUserId);
    if (index < 0) {
      throw ApiException('not found', statusCode: 404);
    }
    final current = list[index];
    final updated = Membership(
      id: current.id,
      userId: current.userId,
      householdId: current.householdId,
      role: current.role,
      joinedAt: current.joinedAt,
    );
    list[index] = updated;
    return updated;
  }

  @override
  Future<void> leave(String householdId) async {
    _households.removeWhere((h) => h.id == householdId);
    _members.remove(householdId);
  }
}
