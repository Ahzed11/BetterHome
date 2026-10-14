package com.betterhome.lists.membership;

import static com.betterhome.lists.membership.FakeHouseholdsServer.ADMIN_SUBJECT;
import static com.betterhome.lists.membership.FakeHouseholdsServer.ADMIN_USER;
import static com.betterhome.lists.membership.FakeHouseholdsServer.HOUSEHOLD;
import static com.betterhome.lists.membership.FakeHouseholdsServer.MEMBER_SUBJECT;
import static com.betterhome.lists.membership.FakeHouseholdsServer.MEMBER_USER;
import static com.betterhome.lists.membership.FakeHouseholdsServer.TOKEN;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.lists.domain.ListException;
import com.betterhome.lists.membership.MembershipGateway.MemberView;
import io.quarkus.test.common.QuarkusTestResource;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
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
    void findsAMemberByAuthSubjectAndMapsTheRole() {
        MemberView admin =
                gateway.findByAuthSubject(HOUSEHOLD_ID, UUID.fromString(ADMIN_SUBJECT))
                        .orElseThrow();
        MemberView member =
                gateway.findByAuthSubject(HOUSEHOLD_ID, UUID.fromString(MEMBER_SUBJECT))
                        .orElseThrow();

        assertEquals(UUID.fromString(ADMIN_USER), admin.userId());
        assertTrue(admin.admin());
        assertEquals(UUID.fromString(MEMBER_USER), member.userId());
        assertFalse(member.admin());
    }

    @Test
    void strangersAndUnknownHouseholdsAreNotMembers() {
        assertTrue(gateway.findByAuthSubject(HOUSEHOLD_ID, UUID.randomUUID()).isEmpty());
        assertTrue(
                gateway.findByAuthSubject(UUID.randomUUID(), UUID.fromString(ADMIN_SUBJECT))
                        .isEmpty());
    }

    @Test
    void everyCallCarriesTheServiceAccountToken() {
        gateway.findByAuthSubject(HOUSEHOLD_ID, UUID.fromString(ADMIN_SUBJECT));

        assertEquals(List.of("Bearer " + TOKEN), FakeHouseholdsServer.AUTHORIZATIONS);
    }

    @Test
    void anOutageIsReportedAsUnavailableNotAsNoMembers() {
        FakeHouseholdsServer.householdsStatus = 503;

        assertThrows(
                ListException.ServiceUnavailable.class,
                () -> gateway.findByAuthSubject(HOUSEHOLD_ID, UUID.fromString(ADMIN_SUBJECT)));
    }

    @Test
    void rejectedServiceTokenIsReportedAsUnavailable() {
        FakeHouseholdsServer.householdsStatus = 401;

        assertThrows(
                ListException.ServiceUnavailable.class,
                () -> gateway.findByAuthSubject(HOUSEHOLD_ID, UUID.fromString(ADMIN_SUBJECT)));
    }
}
