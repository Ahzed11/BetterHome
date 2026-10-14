package com.betterhome.lists;

import static org.junit.jupiter.api.Assertions.assertThrows;

import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceException;
import jakarta.transaction.Transactional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The database enforces integrity on its own, whatever the application does. Runs on the schema
 * Flyway built from scratch in the Dev Services Postgres.
 */
@QuarkusTest
class SchemaConstraintsTest {

    private static final UUID LIST_ID = UUID.fromString("00000000-0000-0000-0000-0000000000a1");
    private static final UUID ITEM_ID = UUID.fromString("00000000-0000-0000-0000-0000000000b1");

    @Inject EntityManager entityManager;
    @Inject TestWorld world;

    @BeforeEach
    void clean() {
        world.reset();
    }

    private void insertList(UUID id, String title) {
        entityManager
                .createNativeQuery(
                        "INSERT INTO list (id, household_id, title, created_by, created_at, "
                                + "updated_at) VALUES (?1, ?2, ?3, ?4, now(), now())")
                .setParameter(1, id)
                .setParameter(2, UUID.randomUUID())
                .setParameter(3, title)
                .setParameter(4, UUID.randomUUID())
                .executeUpdate();
    }

    private void insertItem(
            UUID id, UUID listId, String title, int position, String completion, String deletion) {
        entityManager
                .createNativeQuery(
                        "INSERT INTO item (id, list_id, title, position, creator, completer, "
                                + "completed_at, deleted_by, deleted_at, created_at, updated_at) "
                                + "VALUES (?1, ?2, ?3, ?4, ?5, "
                                + completion
                                + ", "
                                + deletion
                                + ", now(), now())")
                .setParameter(1, id)
                .setParameter(2, listId)
                .setParameter(3, title)
                .setParameter(4, position)
                .setParameter(5, UUID.randomUUID())
                .executeUpdate();
    }

    private static final String UNCHECKED = "NULL, NULL";
    private static final String NOT_DELETED = "NULL, NULL";

    @Test
    @Transactional
    void aWellFormedListAndItemAreAccepted() {
        insertList(LIST_ID, "Groceries");
        insertItem(ITEM_ID, LIST_ID, "Milk", 0, UNCHECKED, NOT_DELETED);
        insertItem(
                UUID.randomUUID(),
                LIST_ID,
                "Eggs",
                1,
                "'" + UUID.randomUUID() + "', now()",
                "'" + UUID.randomUUID() + "', now()");
    }

    @Test
    @Transactional
    void aListNeedsAHouseholdAndANonBlankTitle() {
        assertThrows(PersistenceException.class, () -> insertList(LIST_ID, "   "));
    }

    @Test
    @Transactional
    void aListWithoutAHouseholdIsRejected() {
        assertThrows(
                PersistenceException.class,
                () ->
                        entityManager
                                .createNativeQuery(
                                        "INSERT INTO list (id, title, created_by, created_at, "
                                                + "updated_at) VALUES (?1, 'x', ?2, now(), now())")
                                .setParameter(1, LIST_ID)
                                .setParameter(2, UUID.randomUUID())
                                .executeUpdate());
    }

    @Test
    @Transactional
    void anItemMustBelongToAnExistingList() {
        assertThrows(
                PersistenceException.class,
                () -> insertItem(ITEM_ID, UUID.randomUUID(), "Milk", 0, UNCHECKED, NOT_DELETED));
    }

    @Test
    @Transactional
    void anItemNeedsANonBlankTitleAndANonNegativePosition() {
        insertList(LIST_ID, "Groceries");
        assertThrows(
                PersistenceException.class,
                () -> insertItem(ITEM_ID, LIST_ID, " ", 0, UNCHECKED, NOT_DELETED));
    }

    @Test
    @Transactional
    void aNegativePositionIsRejected() {
        insertList(LIST_ID, "Groceries");
        assertThrows(
                PersistenceException.class,
                () -> insertItem(ITEM_ID, LIST_ID, "Milk", -1, UNCHECKED, NOT_DELETED));
    }

    @Test
    @Transactional
    void positionsAreUniquePerList() {
        insertList(LIST_ID, "Groceries");
        insertItem(ITEM_ID, LIST_ID, "Milk", 0, UNCHECKED, NOT_DELETED);
        assertThrows(
                PersistenceException.class,
                () -> insertItem(UUID.randomUUID(), LIST_ID, "Eggs", 0, UNCHECKED, NOT_DELETED));
    }

    @Test
    @Transactional
    void completerAndCompletedAtComeTogether() {
        insertList(LIST_ID, "Groceries");
        assertThrows(
                PersistenceException.class,
                () ->
                        insertItem(
                                ITEM_ID,
                                LIST_ID,
                                "Milk",
                                0,
                                "'" + UUID.randomUUID() + "', NULL",
                                NOT_DELETED));
    }

    @Test
    @Transactional
    void deletedByAndDeletedAtComeTogether() {
        insertList(LIST_ID, "Groceries");
        assertThrows(
                PersistenceException.class,
                () -> insertItem(ITEM_ID, LIST_ID, "Milk", 0, UNCHECKED, "NULL, now()"));
    }
}
