package com.betterhome.notifications;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.betterhome.notifications.domain.Channel;
import com.betterhome.notifications.domain.NotificationType;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceException;
import jakarta.transaction.Transactional;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/** The database refuses what the domain rules forbid, whatever code writes to it. */
@QuarkusTest
class SchemaConstraintsTest {

    @Inject EntityManager entityManager;

    private int insert(String type, String channel, String key, String title, String payload) {
        return entityManager
                .createNativeQuery(
                        "INSERT INTO notification (id, household_id, user_id, type, channel, title,"
                                + " body, payload, idempotency_key, created_at) VALUES (:id, :id, :id,"
                                + " :type, :channel, :title, 'body', CAST(:payload AS jsonb), :key,"
                                + " NOW())")
                .setParameter("id", UUID.randomUUID())
                .setParameter("type", type)
                .setParameter("channel", channel)
                .setParameter("title", title)
                .setParameter("payload", payload)
                .setParameter("key", key)
                .executeUpdate();
    }

    @Test
    @Transactional
    void everyJavaTypeAndChannelIsAcceptedByTheCheckConstraints() {
        for (NotificationType type : NotificationType.values()) {
            for (Channel channel : Channel.values()) {
                assertEquals(
                        1,
                        insert(
                                type.name(),
                                channel.name(),
                                "schema-ok-" + type + channel,
                                "t",
                                "{}"));
            }
        }
        entityManager
                .createNativeQuery("DELETE FROM notification WHERE idempotency_key LIKE 'schema-%'")
                .executeUpdate();
    }

    @Test
    void unknownTypesChannelsBlankTitlesAndNonObjectPayloadsAreRefused() {
        List<Runnable> bad =
                List.of(
                        () -> insert("party_time", "push", "schema-1", "t", "{}"),
                        () -> insert("overdue", "email", "schema-2", "t", "{}"),
                        () -> insert("overdue", "push", "schema-3", "  ", "{}"),
                        () -> insert("overdue", "push", "schema-4", "t", "[]"),
                        () -> insert("overdue", "push", " ", "t", "{}"));
        for (Runnable statement : bad) {
            assertThrows(
                    PersistenceException.class,
                    () -> io.quarkus.narayana.jta.QuarkusTransaction.requiringNew().run(statement));
        }
    }

    @Test
    void oneEventCannotBeStoredTwiceForTheSameChannel() {
        io.quarkus.narayana.jta.QuarkusTransaction.requiringNew()
                .run(() -> insert("overdue", "push", "schema-dup", "t", "{}"));

        assertThrows(
                PersistenceException.class,
                () ->
                        io.quarkus.narayana.jta.QuarkusTransaction.requiringNew()
                                .run(() -> insert("overdue", "push", "schema-dup", "t", "{}")));
        io.quarkus.narayana.jta.QuarkusTransaction.requiringNew()
                .run(() -> insert("overdue", "in_app", "schema-dup", "t", "{}"));
        io.quarkus.narayana.jta.QuarkusTransaction.requiringNew()
                .run(
                        () ->
                                entityManager
                                        .createNativeQuery(
                                                "DELETE FROM notification WHERE idempotency_key"
                                                        + " LIKE 'schema-%'")
                                        .executeUpdate());
    }
}
