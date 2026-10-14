package com.betterhome.lists.domain;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class ChecklistTest {

    private static final Instant T0 = Instant.parse("2026-03-01T10:00:00Z");
    private static final Instant T1 = Instant.parse("2026-03-02T10:00:00Z");
    private static final UUID HOUSEHOLD = UUID.randomUUID();
    private static final UUID USER = UUID.randomUUID();

    @Test
    void createTrimsTheTitleAndStartsActive() {
        Checklist list = Checklist.create(HOUSEHOLD, "  Groceries ", USER, T0);

        assertEquals("Groceries", list.title);
        assertEquals(HOUSEHOLD, list.householdId);
        assertEquals(USER, list.createdBy);
        assertEquals(T0, list.createdAt);
        assertFalse(list.isArchived());
    }

    @Test
    void blankTitlesAreRejected() {
        assertThrows(
                ListException.BadRequest.class, () -> Checklist.create(HOUSEHOLD, " ", USER, T0));
        assertThrows(
                ListException.BadRequest.class, () -> Checklist.create(HOUSEHOLD, null, USER, T0));
    }

    @Test
    void renameChangesTheTitleAndTouchesUpdatedAt() {
        Checklist list = Checklist.create(HOUSEHOLD, "Groceries", USER, T0);

        list.rename("Weekend", T1);

        assertEquals("Weekend", list.title);
        assertEquals(T1, list.updatedAt);
        assertEquals(T0, list.createdAt);
    }

    @Test
    void archiveFreezesTheList() {
        Checklist list = Checklist.create(HOUSEHOLD, "Groceries", USER, T0);

        list.archive(T1);

        assertTrue(list.isArchived());
        assertEquals(T1, list.archivedAt);
        assertThrows(ListException.Conflict.class, list::requireActive);
        assertThrows(ListException.Conflict.class, () -> list.rename("Other", T1));
        assertThrows(ListException.Conflict.class, () -> list.archive(T1));
        assertEquals("Groceries", list.title);
    }

    @Test
    void checkRecordsWhoAndWhenAndKeepsTheFirstCheck() {
        ChecklistItem item = ChecklistItem.create(UUID.randomUUID(), "Milk", 0, USER, T0);
        UUID other = UUID.randomUUID();

        item.check(USER, T0);
        item.check(other, T1);

        assertTrue(item.isChecked());
        assertEquals(USER, item.completer);
        assertEquals(T0, item.completedAt);
    }

    @Test
    void uncheckClearsTheCompletion() {
        ChecklistItem item = ChecklistItem.create(UUID.randomUUID(), "Milk", 0, USER, T0);
        item.check(USER, T0);

        item.uncheck(T1);

        assertFalse(item.isChecked());
        assertNull(item.completer);
        assertNull(item.completedAt);
        assertEquals(T1, item.updatedAt);
    }

    @Test
    void uncheckingAnUncheckedItemChangesNothing() {
        ChecklistItem item = ChecklistItem.create(UUID.randomUUID(), "Milk", 0, USER, T0);

        item.uncheck(T1);

        assertEquals(T0, item.updatedAt);
    }

    @Test
    void softDeleteKeepsWhoAndWhen() {
        ChecklistItem item = ChecklistItem.create(UUID.randomUUID(), "Milk", 0, USER, T0);
        UUID deleter = UUID.randomUUID();

        item.softDelete(deleter, T1);

        assertEquals(deleter, item.deletedBy);
        assertEquals(T1, item.deletedAt);
    }

    @Test
    void renameTrimsAndRejectsBlank() {
        ChecklistItem item = ChecklistItem.create(UUID.randomUUID(), "Milk", 0, USER, T0);

        item.rename(" Oat milk ", T1);

        assertEquals("Oat milk", item.title);
        assertThrows(ListException.BadRequest.class, () -> item.rename("", T1));
        assertEquals("Oat milk", item.title);
    }
}
