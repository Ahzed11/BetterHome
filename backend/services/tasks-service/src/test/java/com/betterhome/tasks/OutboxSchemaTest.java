package com.betterhome.tasks;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.util.List;
import org.junit.jupiter.api.Test;

@QuarkusTest
class OutboxSchemaTest {

    @Inject EntityManager entityManager;

    private List<String> outboxColumns() {
        return QuarkusTransaction.requiringNew()
                .call(
                        () ->
                                entityManager
                                        .createNativeQuery(
                                                "SELECT column_name FROM information_schema.columns"
                                                        + " WHERE table_name = 'notification_outbox'",
                                                String.class)
                                        .getResultList());
    }

    @Test
    void outboxNoLongerHasTheTextColumns() {
        List<String> columns = outboxColumns();

        assertFalse(columns.contains("title"));
        assertFalse(columns.contains("body"));
        assertTrue(columns.contains("payload_json"));
    }
}
