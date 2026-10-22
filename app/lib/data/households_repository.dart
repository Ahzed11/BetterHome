import 'package:betterhome/data/api_mappers.dart';
import 'package:betterhome/data/api_support.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome_api/api.dart' as api;
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

  /// Deletes the signed-in person's account. Answers 409 while they are the only admin of a
  /// household that has other members.
  Future<void> deleteMyAccount();
}

class HttpHouseholdsRepository implements HouseholdsRepository {
  HttpHouseholdsRepository({
    required String baseUrl,
    required String Function() accessToken,
    http.Client? client,
  }) : _client = buildApiClient(
         baseUrl: baseUrl,
         accessToken: accessToken,
         client: client,
       );

  final api.ApiClient _client;

  api.UsersApi get _users => api.UsersApi(_client);
  api.HouseholdsApi get _households => api.HouseholdsApi(_client);
  api.MembershipsApi get _memberships => api.MembershipsApi(_client);
  api.InvitationsApi get _invitations => api.InvitationsApi(_client);

  @override
  Future<UserProfile> syncMe({
    required String email,
    String? givenName,
    String? familyName,
    String language = 'en',
    String timezone = 'UTC',
  }) async {
    return userProfileFromApi(
      await call(
        () => _users.syncMyProfile(
          api.SyncUserRequest(
            email: email,
            givenName: givenName,
            familyName: familyName,
            language: language,
            timezone: timezone,
          ),
        ),
      ),
    );
  }

  @override
  Future<UserProfile> getMe() async =>
      userProfileFromApi(await call(_users.getMyProfile));

  @override
  Future<List<Household>> listHouseholds() async {
    final list = await call(_households.listMyHouseholds);
    return list.map(householdFromApi).toList();
  }

  @override
  Future<Household> createHousehold({
    required String name,
    required String timezone,
  }) async {
    return householdFromApi(
      await call(
        () => _households.createHousehold(
          api.CreateHouseholdRequest(name: name, timezone: timezone),
        ),
      ),
    );
  }

  @override
  Future<Household> getHousehold(String householdId) async =>
      householdFromApi(await call(() => _households.getHousehold(householdId)));

  @override
  Future<List<Membership>> listMembers(String householdId) async {
    final list = await call(() => _memberships.listMembers(householdId));
    return list.map(membershipFromApi).toList();
  }

  @override
  Future<Invitation> createInvitation({
    required String householdId,
    required String email,
    MembershipRole role = MembershipRole.member,
  }) async {
    return invitationFromApi(
      await call(
        () => _invitations.createInvitation(
          householdId,
          api.CreateInvitationRequest(
            email: email,
            role: api.MembershipRole.values.byName(role.name),
          ),
        ),
      ),
    );
  }

  @override
  Future<Membership> acceptInvitation(String token) async =>
      membershipFromApi(await call(() => _invitations.acceptInvitation(token)));

  @override
  Future<Membership> setAway(String householdId, String userId) async {
    return membershipFromApi(
      await call(
        () => _memberships.setMemberAway(
          householdId,
          userId,
          api.SetAwayRequest(),
        ),
      ),
    );
  }

  @override
  Future<Membership> clearAway(String householdId, String userId) async {
    return membershipFromApi(
      await call(() => _memberships.clearMemberAway(householdId, userId)),
    );
  }

  @override
  Future<void> leave(String householdId) =>
      callVoid(() => _memberships.leaveHousehold(householdId));

  @override
  Future<void> deleteMyAccount() => callVoid(_users.deleteMyAccount);
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

  /// Adds another person to a household, as if they had joined by invitation.
  void addMember(
    String householdId, {
    required String memberUserId,
    required String givenName,
    required String familyName,
    MembershipRole role = MembershipRole.member,
  }) {
    _members
        .putIfAbsent(householdId, () => [])
        .add(
          Membership(
            id: 'm-$householdId-$memberUserId',
            userId: memberUserId,
            householdId: householdId,
            role: role,
            joinedAt: DateTime.utc(2026, 1, 2),
            givenName: givenName,
            familyName: familyName,
          ),
        );
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
      givenName: current.givenName,
      familyName: current.familyName,
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
      givenName: current.givenName,
      familyName: current.familyName,
    );
    list[index] = updated;
    return updated;
  }

  @override
  Future<void> leave(String householdId) async {
    _households.removeWhere((h) => h.id == householdId);
    _members.remove(householdId);
  }

  @override
  Future<void> deleteMyAccount() async {
    final blocked = _households.any((household) {
      final members = _members[household.id] ?? const <Membership>[];
      final others = members.where((m) => m.userId != userId);
      return others.isNotEmpty &&
          members.any(
            (m) => m.userId == userId && m.role == MembershipRole.admin,
          ) &&
          !others.any((m) => m.role == MembershipRole.admin);
    });
    if (blocked) {
      throw ApiException('sole admin of a household', statusCode: 409);
    }
    for (final household in List.of(_households)) {
      final others = (_members[household.id] ?? const <Membership>[]).where(
        (m) => m.userId != userId,
      );
      if (others.isEmpty) {
        _households.remove(household);
        _members.remove(household.id);
      } else {
        _members[household.id] = others.toList();
      }
    }
    _me = null;
  }
}
