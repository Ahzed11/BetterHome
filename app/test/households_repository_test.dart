import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fake repository supports create invite and away', () async {
    final repo = FakeHouseholdsRepository();
    await repo.syncMe(email: 'a@example.com', givenName: 'A');
    final household = await repo.createHousehold(name: 'Home', timezone: 'UTC');
    expect(household.name, 'Home');

    final invite = await repo.createInvitation(
      householdId: household.id,
      email: 'b@example.com',
      role: MembershipRole.member,
    );
    expect(invite.token, isNotEmpty);

    final away = await repo.setAway(household.id, repo.userId);
    expect(away.isAway, isTrue);
    final cleared = await repo.clearAway(household.id, repo.userId);
    expect(cleared.isAway, isFalse);
  });
}
