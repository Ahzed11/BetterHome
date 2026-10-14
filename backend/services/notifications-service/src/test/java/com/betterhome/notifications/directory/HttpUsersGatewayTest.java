package com.betterhome.notifications.directory;

import static com.betterhome.notifications.directory.FakeHouseholdsServer.FRENCH_SUBJECT;
import static com.betterhome.notifications.directory.FakeHouseholdsServer.FRENCH_USER;
import static com.betterhome.notifications.directory.FakeHouseholdsServer.TOKEN;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.notifications.directory.UsersGateway.UserView;
import com.betterhome.notifications.domain.NotificationException;
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
class HttpUsersGatewayTest {

    @Inject HttpUsersGateway gateway;

    @BeforeEach
    @AfterEach
    void reset() {
        FakeHouseholdsServer.AUTHORIZATIONS.clear();
        FakeHouseholdsServer.householdsStatus = 200;
    }

    @Test
    void findsAUserByIdAndBySubjectWithTheLanguage() {
        UserView byId = gateway.findById(UUID.fromString(FRENCH_USER)).orElseThrow();
        UserView bySubject =
                gateway.findByAuthSubject(UUID.fromString(FRENCH_SUBJECT)).orElseThrow();

        assertEquals(new UserView(UUID.fromString(FRENCH_USER), "fr"), byId);
        assertEquals(byId, bySubject);
    }

    @Test
    void unknownUsersAreAbsentNotAnError() {
        assertTrue(gateway.findById(UUID.randomUUID()).isEmpty());
        assertTrue(gateway.findByAuthSubject(UUID.randomUUID()).isEmpty());
    }

    @Test
    void everyCallCarriesTheServiceAccountToken() {
        gateway.findById(UUID.fromString(FRENCH_USER));
        gateway.findByAuthSubject(UUID.fromString(FRENCH_SUBJECT));

        assertEquals(
                List.of("Bearer " + TOKEN, "Bearer " + TOKEN), FakeHouseholdsServer.AUTHORIZATIONS);
    }

    @Test
    void anOutageIsReportedAsUnavailableNotAsNoSuchUser() {
        FakeHouseholdsServer.householdsStatus = 503;

        assertThrows(
                NotificationException.ServiceUnavailable.class,
                () -> gateway.findById(UUID.fromString(FRENCH_USER)));
        assertThrows(
                NotificationException.ServiceUnavailable.class,
                () -> gateway.findByAuthSubject(UUID.fromString(FRENCH_SUBJECT)));
    }

    @Test
    void aRejectedServiceTokenIsReportedAsUnavailable() {
        FakeHouseholdsServer.householdsStatus = 401;

        assertThrows(
                NotificationException.ServiceUnavailable.class,
                () -> gateway.findById(UUID.fromString(FRENCH_USER)));
    }

    @Test
    void aDroppedConnectionIsReportedAsUnavailable() {
        FakeHouseholdsServer.householdsStatus = -1;

        assertThrows(
                NotificationException.ServiceUnavailable.class,
                () -> gateway.findById(UUID.fromString(FRENCH_USER)));
    }
}
