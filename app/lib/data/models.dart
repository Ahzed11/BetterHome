enum MembershipRole { admin, member }

class UserProfile {
  const UserProfile({
    required this.id,
    required this.authSubject,
    required this.email,
    required this.givenName,
    required this.familyName,
    required this.language,
    required this.timezone,
  });

  final String id;
  final String authSubject;
  final String email;
  final String givenName;
  final String familyName;
  final String language;
  final String timezone;
}

class Household {
  const Household({
    required this.id,
    required this.name,
    required this.timezone,
    required this.reminderDaysBefore,
    required this.reminderTime,
    required this.createdBy,
  });

  final String id;
  final String name;
  final String timezone;
  final int reminderDaysBefore;
  final String reminderTime;
  final String createdBy;
}

class Membership {
  const Membership({
    required this.id,
    required this.userId,
    required this.householdId,
    required this.role,
    required this.joinedAt,
    this.awayFrom,
    this.awayUntil,
    this.awaySetBy,
  });

  final String id;
  final String userId;
  final String householdId;
  final MembershipRole role;
  final DateTime joinedAt;
  final DateTime? awayFrom;
  final DateTime? awayUntil;
  final String? awaySetBy;

  bool get isAway => awayFrom != null;
}

class Invitation {
  const Invitation({
    required this.id,
    required this.householdId,
    required this.email,
    required this.role,
    required this.token,
    required this.expiresAt,
    this.acceptedAt,
  });

  final String id;
  final String householdId;
  final String email;
  final MembershipRole role;
  final String token;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
