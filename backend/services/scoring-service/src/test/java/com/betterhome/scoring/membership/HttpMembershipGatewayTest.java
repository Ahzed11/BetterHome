package com.betterhome.scoring.membership;

import static com.betterhome.scoring.membership.FakeHouseholdsServer.ADMIN_SUBJECT;
import static com.betterhome.scoring.membership.FakeHouseholdsServer.ADMIN_USER;
import static com.betterhome.scoring.membership.FakeHouseholdsServer.HOUSEHOLD;
import static com.betterhome.scoring.membership.FakeHouseholdsServer.MEMBER_SUBJECT;
import static com.betterhome.scoring.membership.FakeHouseholdsServer.MEMBER_USER;
import static com.betterhome.scoring.membership.FakeHouseholdsServer.TOKEN;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.scoring.domain.ScoringException;
import com.betterhome.scoring.membership.MembershipGateway.MemberView;
import io.quarkus.test.common.QuarkusTestResource;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
@QuarkusTestResource(value = FakeHouseholdsServer.class, restrictToAnnotatedClass = true)
class HttpMembershipGatewayTest {

    private static final UUID HOUSEHOLD_ID = UUID.fromString(HOUSEHOLD);

    @Inject HttpMembershipGateway gateway;

    @BeforeEach
    @AfterEach
    void reset() {
        FakeHouseholdsServer.AUTHORIZATIONS.clear();
        FakeHouseholdsServer.householdsStatus = 200;
        FakeHouseholdsServer.timezone = "Europe/Brussels";
    }

    @Test
    void findsAMemberByAuthSubjectAndMapsRoleAndAway() {
        MemberView admin =
                gateway.findByAuthSubject(HOUSEHOLD_ID, UUID.fromString(ADMIN_SUBJECT))
                        .orElseThrow();
        MemberView member =
                gateway.findByAuthSubject(HOUSEHOLD_ID, UUID.fromString(MEMBER_SUBJECT))
                        .orElseThrow();

        assertEquals(UUID.fromString(ADMIN_USER), admin.userId());
        assertTrue(admin.admin());
        assertFalse(admin.away());
        assertFalse(member.admin());
        assertTrue(member.away());
        assertTrue(admin.membershipOrder() < member.membershipOrder());
    }

    @Test
    void strangersAndUnknownHouseholdsAreNotMembers() {
        assertTrue(gateway.findByAuthSubject(HOUSEHOLD_ID, UUID.randomUUID()).isEmpty());
        assertTrue(
                gateway.findByAuthSubject(UUID.randomUUID(), UUID.fromString(ADMIN_SUBJECT))
                        .isEmpty());
        assertEquals(List.of(), gateway.listActiveMembers(UUID.randomUUID()));
    }

    @Test
    void listsEveryActiveMemberInJoiningOrderAwayIncluded() {
        assertEquals(
                List.of(UUID.fromString(ADMIN_USER), UUID.fromString(MEMBER_USER)),
                gateway.listActiveMembers(HOUSEHOLD_ID).stream().map(MemberView::userId).toList());
    }

    @Test
    void everyCallCarriesTheServiceAccountToken() {
        gateway.listActiveMembers(HOUSEHOLD_ID);

        assertEquals(List.of("Bearer " + TOKEN), FakeHouseholdsServer.AUTHORIZATIONS);
    }

    @Test
    void anOutageIsReportedAsUnavailableNotAsNoMembers() {
        FakeHouseholdsServer.householdsStatus = 503;

        assertThrows(
                ScoringException.ServiceUnavailable.class,
                () -> gateway.listActiveMembers(HOUSEHOLD_ID));
        assertThrows(
                ScoringException.ServiceUnavailable.class,
                () -> gateway.findByAuthSubject(HOUSEHOLD_ID, UUID.fromString(ADMIN_SUBJECT)));
    }

    @Test
    void aRejectedServiceTokenIsReportedAsUnavailable() {
        FakeHouseholdsServer.householdsStatus = 401;

        assertThrows(
                ScoringException.ServiceUnavailable.class,
                () -> gateway.listActiveMembers(HOUSEHOLD_ID));
    }

    @Test
    void aDroppedConnectionIsReportedAsUnavailable() {
        FakeHouseholdsServer.householdsStatus = -1;

        assertThrows(
                ScoringException.ServiceUnavailable.class,
                () -> gateway.listActiveMembers(HOUSEHOLD_ID));
    }

    @Test
    void theHouseholdZoneComesFromItsSettingsWithTheServiceToken() {
        assertEquals(ZoneId.of("Europe/Brussels"), gateway.householdZone(HOUSEHOLD_ID));
        assertEquals("Bearer " + TOKEN, FakeHouseholdsServer.AUTHORIZATIONS.getLast());
    }

    @Test
    void aZoneThatIsNotValidFallsBackToUtc() {
        FakeHouseholdsServer.timezone = "Mars/Olympus";

        assertEquals(ZoneOffset.UTC, gateway.householdZone(HOUSEHOLD_ID));
    }

    @Test
    void anUnknownHouseholdHasNoZoneSoUtcIsUsed() {
        assertEquals(ZoneOffset.UTC, gateway.householdZone(UUID.randomUUID()));
    }

    @Test
    void aFailingHouseholdsServiceMakesTheZoneLookupUnavailable() {
        FakeHouseholdsServer.householdsStatus = 503;
        assertThrows(
                ScoringException.ServiceUnavailable.class,
                () -> gateway.householdZone(HOUSEHOLD_ID));

        FakeHouseholdsServer.householdsStatus = -1;
        assertThrows(
                ScoringException.ServiceUnavailable.class,
                () -> gateway.householdZone(HOUSEHOLD_ID));
    }
}
