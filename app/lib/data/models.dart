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

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      authSubject: json['authSubject'] as String,
      email: json['email'] as String,
      givenName: json['givenName'] as String? ?? '',
      familyName: json['familyName'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      timezone: json['timezone'] as String? ?? 'UTC',
    );
  }
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

  factory Household.fromJson(Map<String, dynamic> json) {
    return Household(
      id: json['id'] as String,
      name: json['name'] as String,
      timezone: json['timezone'] as String,
      reminderDaysBefore: json['reminderDaysBefore'] as int? ?? 0,
      reminderTime: json['reminderTime'] as String? ?? '08:00:00',
      createdBy: json['createdBy'] as String,
    );
  }
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

  factory Membership.fromJson(Map<String, dynamic> json) {
    return Membership(
      id: json['id'] as String,
      userId: json['userId'] as String,
      householdId: json['householdId'] as String,
      role: MembershipRole.values.byName(json['role'] as String),
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      awayFrom: json['awayFrom'] == null
          ? null
          : DateTime.parse(json['awayFrom'] as String),
      awayUntil: json['awayUntil'] == null
          ? null
          : DateTime.parse(json['awayUntil'] as String),
      awaySetBy: json['awaySetBy'] as String?,
    );
  }
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

  factory Invitation.fromJson(Map<String, dynamic> json) {
    return Invitation(
      id: json['id'] as String,
      householdId: json['householdId'] as String,
      email: json['email'] as String,
      role: MembershipRole.values.byName(json['role'] as String),
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      acceptedAt: json['acceptedAt'] == null
          ? null
          : DateTime.parse(json['acceptedAt'] as String),
    );
  }
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
