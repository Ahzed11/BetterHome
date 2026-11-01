package com.betterhome.tasks;

import static org.junit.jupiter.api.Assertions.assertEquals;

import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.util.List;
import org.junit.jupiter.api.Test;

/** The shape of the outbox table once the rendered text moved to notifications-service. */
@QuarkusTest
class OutboxSchemaTest {

    @Inject EntityManager entityManager;

    @Test
    void theOutboxKeepsNoRenderedTitleOrBody() {
        List<?> columns =
                entityManager
                        .createNativeQuery(
                                "SELECT column_name FROM information_schema.columns"
                                        + " WHERE table_name = 'notification_outbox'"
                                        + " AND column_name IN ('title', 'body')")
                        .getResultList();

        assertEquals(List.of(), columns);
    }
}
