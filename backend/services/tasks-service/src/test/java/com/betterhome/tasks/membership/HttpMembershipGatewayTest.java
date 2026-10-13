package com.betterhome.tasks.membership;

import static com.betterhome.tasks.membership.FakeHouseholdsServer.ADMIN_SUBJECT;
import static com.betterhome.tasks.membership.FakeHouseholdsServer.ADMIN_USER;
import static com.betterhome.tasks.membership.FakeHouseholdsServer.HOUSEHOLD;
import static com.betterhome.tasks.membership.FakeHouseholdsServer.MEMBER_SUBJECT;
import static com.betterhome.tasks.membership.FakeHouseholdsServer.MEMBER_USER;
import static com.betterhome.tasks.membership.FakeHouseholdsServer.TOKEN;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.tasks.domain.TaskException;
import com.betterhome.tasks.membership.MembershipGateway.HouseholdSettings;
import com.betterhome.tasks.membership.MembershipGateway.MemberView;
import io.quarkus.test.common.QuarkusTestResource;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.LocalTime;
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
        assertTrue(gateway.findByAuthSubject(UUID.randomUUID(), UUID.fromString(ADMIN_SUBJECT))
                .isEmpty());
    }

    @Test
    void eligibleMembersSkipAwayWhileActiveMembersKeepEveryone() {
        assertEquals(List.of(UUID.fromString(ADMIN_USER)), gateway.listEligibleAssigneeIds(HOUSEHOLD_ID));
        assertEquals(
                List.of(UUID.fromString(ADMIN_USER), UUID.fromString(MEMBER_USER)),
                gateway.listActiveMemberIds(HOUSEHOLD_ID));
        assertEquals(List.of(), gateway.listEligibleAssigneeIds(UUID.randomUUID()));
    }

    @Test
    void readsHouseholdSettings() {
        assertEquals(
                new HouseholdSettings("Europe/Paris", 1, LocalTime.of(8, 30)),
                gateway.householdSettings(HOUSEHOLD_ID));
        assertThrows(
                TaskException.NotFound.class, () -> gateway.householdSettings(UUID.randomUUID()));
    }

    @Test
    void everyCallCarriesTheServiceAccountToken() {
        gateway.listActiveMemberIds(HOUSEHOLD_ID);
        gateway.householdSettings(HOUSEHOLD_ID);

        assertEquals(List.of("Bearer " + TOKEN, "Bearer " + TOKEN), FakeHouseholdsServer.AUTHORIZATIONS);
    }

    @Test
    void anOutageIsReportedAsUnavailableNotAsNoMembers() {
        FakeHouseholdsServer.householdsStatus = 503;

        assertThrows(
                TaskException.ServiceUnavailable.class,
                () -> gateway.listEligibleAssigneeIds(HOUSEHOLD_ID));
        assertThrows(
                TaskException.ServiceUnavailable.class,
                () -> gateway.findByAuthSubject(HOUSEHOLD_ID, UUID.fromString(ADMIN_SUBJECT)));
    }

    @Test
    void rejectedServiceTokenIsReportedAsUnavailable() {
        FakeHouseholdsServer.householdsStatus = 401;

        assertThrows(
                TaskException.ServiceUnavailable.class,
                () -> gateway.householdSettings(HOUSEHOLD_ID));
    }
}
