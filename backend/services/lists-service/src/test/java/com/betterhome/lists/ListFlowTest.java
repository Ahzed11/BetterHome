package com.betterhome.lists;

import static com.betterhome.lists.TestWorld.ADMIN_SUBJECT;
import static com.betterhome.lists.TestWorld.ADMIN_USER;
import static com.betterhome.lists.TestWorld.HOUSEHOLD;
import static com.betterhome.lists.TestWorld.LEFT_SUBJECT;
import static com.betterhome.lists.TestWorld.MEMBER_SUBJECT;
import static com.betterhome.lists.TestWorld.MEMBER_USER;
import static com.betterhome.lists.TestWorld.OTHER_ADMIN_SUBJECT;
import static com.betterhome.lists.TestWorld.OTHER_HOUSEHOLD;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.lists.domain.Checklist;
import com.betterhome.lists.domain.ChecklistItem;
import com.betterhome.lists.domain.ListException;
import com.betterhome.lists.service.ChecklistService;
import com.betterhome.lists.service.ItemService;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class ListFlowTest {

    private static final Instant T0 = Instant.parse("2026-03-01T10:00:00Z");
    private static final Instant T1 = Instant.parse("2026-03-01T11:00:00Z");
    private static final Instant T2 = Instant.parse("2026-03-01T12:00:00Z");

    @Inject TestWorld world;
    @Inject FixedClock clock;
    @Inject ChecklistService lists;
    @Inject ItemService items;

    @BeforeEach
    void seed() {
        world.reset();
        clock.set(T0);
    }

    private Checklist createList(String title) {
        return world.asUser(ADMIN_SUBJECT, () -> lists.create(HOUSEHOLD, title));
    }

    private ChecklistItem addItem(UUID listId, String title) {
        return world.asUser(MEMBER_SUBJECT, () -> items.add(HOUSEHOLD, listId, title));
    }

    @Test
    void anAdminCreatesRenamesAndArchivesAList() {
        Checklist list = createList(" Groceries ");
        assertEquals("Groceries", list.title);
        assertEquals(ADMIN_USER, list.createdBy);
        assertEquals(HOUSEHOLD, list.householdId);
        assertEquals(T0, list.createdAt);

        clock.set(T1);
        Checklist renamed =
                world.asUser(ADMIN_SUBJECT, () -> lists.rename(HOUSEHOLD, list.id, "Weekend"));
        assertEquals("Weekend", renamed.title);
        assertEquals(T1, renamed.updatedAt);

        clock.set(T2);
        Checklist archived = world.asUser(ADMIN_SUBJECT, () -> lists.archive(HOUSEHOLD, list.id));
        assertEquals(T2, archived.archivedAt);
        assertEquals(T2, world.reload(list.id).archivedAt);
    }

    @Test
    void listsHideArchivedUnlessAskedAndStayInCreationOrder() {
        Checklist first = createList("First");
        clock.set(T1);
        Checklist second = createList("Second");
        clock.set(T2);
        world.asUser(ADMIN_SUBJECT, () -> lists.archive(HOUSEHOLD, first.id));

        List<Checklist> visible = world.asUser(MEMBER_SUBJECT, () -> lists.list(HOUSEHOLD, false));
        List<Checklist> all = world.asUser(MEMBER_SUBJECT, () -> lists.list(HOUSEHOLD, true));

        assertEquals(List.of(second.id), visible.stream().map(l -> l.id).toList());
        assertEquals(List.of(first.id, second.id), all.stream().map(l -> l.id).toList());
    }

    @Test
    void listsOfAnotherHouseholdAreNeverVisibleNorReachable() {
        Checklist mine = createList("Mine");
        Checklist theirs = world.seedList(OTHER_HOUSEHOLD, "Theirs", T0);

        List<Checklist> visible = world.asUser(ADMIN_SUBJECT, () -> lists.list(HOUSEHOLD, true));

        assertEquals(List.of(mine.id), visible.stream().map(l -> l.id).toList());
        world.runAs(
                ADMIN_SUBJECT,
                () -> {
                    assertThrows(
                            ListException.NotFound.class,
                            () -> lists.rename(HOUSEHOLD, theirs.id, "Hijacked"));
                    assertThrows(
                            ListException.NotFound.class,
                            () -> items.add(HOUSEHOLD, theirs.id, "Sneaky"));
                    assertThrows(
                            ListException.NotFound.class, () -> items.list(HOUSEHOLD, theirs.id));
                });
        assertEquals("Theirs", world.reload(theirs.id).title);
    }

    @Test
    void membersAppendItemsInPositionOrderRecordingTheCreator() {
        Checklist list = createList("Groceries");

        ChecklistItem milk = addItem(list.id, "Milk");
        ChecklistItem eggs = addItem(list.id, "Eggs");
        ChecklistItem bread = addItem(list.id, "Bread");

        assertEquals(List.of(0, 1, 2), List.of(milk.position, eggs.position, bread.position));
        assertEquals(MEMBER_USER, milk.creator);
        List<ChecklistItem> listed =
                world.asUser(ADMIN_SUBJECT, () -> items.list(HOUSEHOLD, list.id));
        assertEquals(List.of("Milk", "Eggs", "Bread"), listed.stream().map(i -> i.title).toList());
    }

    @Test
    void positionsAreNeverReusedAfterADelete() {
        Checklist list = createList("Groceries");
        addItem(list.id, "Milk");
        ChecklistItem eggs = addItem(list.id, "Eggs");
        world.runAs(MEMBER_SUBJECT, () -> items.delete(HOUSEHOLD, list.id, eggs.id));

        ChecklistItem bread = addItem(list.id, "Bread");

        assertEquals(2, bread.position);
    }

    @Test
    void checkingRecordsWhoAndWhenAndUncheckingClearsIt() {
        Checklist list = createList("Groceries");
        ChecklistItem milk = addItem(list.id, "Milk");

        clock.set(T1);
        ChecklistItem checked =
                world.asUser(ADMIN_SUBJECT, () -> items.check(HOUSEHOLD, list.id, milk.id));
        assertEquals(ADMIN_USER, checked.completer);
        assertEquals(T1, checked.completedAt);

        clock.set(T2);
        ChecklistItem again =
                world.asUser(MEMBER_SUBJECT, () -> items.check(HOUSEHOLD, list.id, milk.id));
        assertEquals(ADMIN_USER, again.completer);
        assertEquals(T1, again.completedAt);

        ChecklistItem unchecked =
                world.asUser(MEMBER_SUBJECT, () -> items.uncheck(HOUSEHOLD, list.id, milk.id));
        assertNull(unchecked.completer);
        assertNull(unchecked.completedAt);
        assertNull(world.reloadItem(milk.id).completer);
    }

    @Test
    void anyMemberEditsAnItemTitle() {
        Checklist list = createList("Groceries");
        ChecklistItem milk = addItem(list.id, "Milk");

        ChecklistItem edited =
                world.asUser(
                        ADMIN_SUBJECT, () -> items.rename(HOUSEHOLD, list.id, milk.id, "Oat milk"));

        assertEquals("Oat milk", edited.title);
        assertEquals("Oat milk", world.reloadItem(milk.id).title);
        world.runAs(
                MEMBER_SUBJECT,
                () ->
                        assertThrows(
                                ListException.BadRequest.class,
                                () -> items.rename(HOUSEHOLD, list.id, milk.id, " ")));
    }

    @Test
    void deletingIsSoftKeepsWhoAndWhenAndHidesTheItem() {
        Checklist list = createList("Groceries");
        ChecklistItem milk = addItem(list.id, "Milk");
        addItem(list.id, "Eggs");

        clock.set(T1);
        world.runAs(MEMBER_SUBJECT, () -> items.delete(HOUSEHOLD, list.id, milk.id));

        ChecklistItem row = world.reloadItem(milk.id);
        assertNotNull(row);
        assertEquals(MEMBER_USER, row.deletedBy);
        assertEquals(T1, row.deletedAt);
        List<ChecklistItem> live =
                world.asUser(ADMIN_SUBJECT, () -> items.list(HOUSEHOLD, list.id));
        assertEquals(List.of("Eggs"), live.stream().map(i -> i.title).toList());
        world.runAs(
                ADMIN_SUBJECT,
                () -> {
                    assertThrows(
                            ListException.NotFound.class,
                            () -> items.check(HOUSEHOLD, list.id, milk.id));
                    assertThrows(
                            ListException.NotFound.class,
                            () -> items.delete(HOUSEHOLD, list.id, milk.id));
                });
    }

    @Test
    void anItemIsOnlyReachableThroughItsOwnList() {
        Checklist groceries = createList("Groceries");
        Checklist packing = createList("Packing");
        ChecklistItem milk = addItem(groceries.id, "Milk");

        world.runAs(
                MEMBER_SUBJECT,
                () ->
                        assertThrows(
                                ListException.NotFound.class,
                                () -> items.check(HOUSEHOLD, packing.id, milk.id)));
    }

    @Test
    void resetUnchecksEveryLiveItemAndLeavesDeletedOnesAlone() {
        Checklist list = createList("Packing");
        ChecklistItem socks = addItem(list.id, "Socks");
        ChecklistItem shoes = addItem(list.id, "Shoes");
        ChecklistItem gone = addItem(list.id, "Gone");
        addItem(list.id, "Hat");
        world.runAs(
                ADMIN_SUBJECT,
                () -> {
                    items.check(HOUSEHOLD, list.id, socks.id);
                    items.check(HOUSEHOLD, list.id, shoes.id);
                    items.check(HOUSEHOLD, list.id, gone.id);
                    items.delete(HOUSEHOLD, list.id, gone.id);
                });
        clock.set(T1);

        List<ChecklistItem> result =
                world.asUser(ADMIN_SUBJECT, () -> items.reset(HOUSEHOLD, list.id));

        assertEquals(3, result.size());
        assertTrue(result.stream().noneMatch(ChecklistItem::isChecked));
        assertTrue(result.stream().allMatch(i -> i.completer == null));
        ChecklistItem deleted = world.reloadItem(gone.id);
        assertTrue(deleted.isChecked());
        assertEquals(ADMIN_USER, deleted.completer);
    }

    @Test
    void aMemberCannotResetAList() {
        Checklist list = createList("Packing");
        ChecklistItem socks = addItem(list.id, "Socks");
        world.runAs(MEMBER_SUBJECT, () -> items.check(HOUSEHOLD, list.id, socks.id));

        world.runAs(
                MEMBER_SUBJECT,
                () ->
                        assertThrows(
                                ListException.Forbidden.class,
                                () -> items.reset(HOUSEHOLD, list.id)));

        assertTrue(world.reloadItem(socks.id).isChecked());
    }

    @Test
    void resetOnlyTouchesItsOwnList() {
        Checklist packing = createList("Packing");
        Checklist groceries = createList("Groceries");
        ChecklistItem milk = addItem(groceries.id, "Milk");
        world.runAs(MEMBER_SUBJECT, () -> items.check(HOUSEHOLD, groceries.id, milk.id));

        world.runAs(ADMIN_SUBJECT, () -> items.reset(HOUSEHOLD, packing.id));

        assertTrue(world.reloadItem(milk.id).isChecked());
    }

    @Test
    void anArchivedListRejectsEveryItemChangeButStaysReadable() {
        Checklist list = createList("Old");
        ChecklistItem milk = addItem(list.id, "Milk");
        world.runAs(ADMIN_SUBJECT, () -> items.check(HOUSEHOLD, list.id, milk.id));
        world.runAs(ADMIN_SUBJECT, () -> lists.archive(HOUSEHOLD, list.id));

        world.runAs(
                MEMBER_SUBJECT,
                () -> {
                    assertThrows(
                            ListException.Conflict.class, () -> items.add(HOUSEHOLD, list.id, "x"));
                    assertThrows(
                            ListException.Conflict.class,
                            () -> items.rename(HOUSEHOLD, list.id, milk.id, "y"));
                    assertThrows(
                            ListException.Conflict.class,
                            () -> items.uncheck(HOUSEHOLD, list.id, milk.id));
                    assertThrows(
                            ListException.Conflict.class,
                            () -> items.delete(HOUSEHOLD, list.id, milk.id));
                    assertEquals(1, items.list(HOUSEHOLD, list.id).size());
                });
        world.runAs(
                ADMIN_SUBJECT,
                () ->
                        assertThrows(
                                ListException.Conflict.class,
                                () -> items.reset(HOUSEHOLD, list.id)));
        ChecklistItem unchanged = world.reloadItem(milk.id);
        assertTrue(unchanged.isChecked());
        assertNull(unchanged.deletedAt);
        assertEquals("Milk", unchanged.title);
    }

    @Test
    void strangersAndFormerMembersCannotTouchAnything() {
        Checklist list = createList("Groceries");
        ChecklistItem milk = addItem(list.id, "Milk");

        for (String subject : List.of(LEFT_SUBJECT, OTHER_ADMIN_SUBJECT)) {
            world.runAs(
                    subject,
                    () -> {
                        assertThrows(
                                ListException.Forbidden.class, () -> lists.list(HOUSEHOLD, true));
                        assertThrows(
                                ListException.Forbidden.class, () -> lists.create(HOUSEHOLD, "x"));
                        assertThrows(
                                ListException.Forbidden.class,
                                () -> items.add(HOUSEHOLD, list.id, "x"));
                        assertThrows(
                                ListException.Forbidden.class,
                                () -> items.check(HOUSEHOLD, list.id, milk.id));
                        assertThrows(
                                ListException.Forbidden.class,
                                () -> items.reset(HOUSEHOLD, list.id));
                    });
        }
        assertFalse(world.reloadItem(milk.id).isChecked());
    }

    @Test
    void membersCannotCreateRenameOrArchiveLists() {
        Checklist list = createList("Groceries");

        world.runAs(
                MEMBER_SUBJECT,
                () -> {
                    assertThrows(ListException.Forbidden.class, () -> lists.create(HOUSEHOLD, "x"));
                    assertThrows(
                            ListException.Forbidden.class,
                            () -> lists.rename(HOUSEHOLD, list.id, "x"));
                    assertThrows(
                            ListException.Forbidden.class, () -> lists.archive(HOUSEHOLD, list.id));
                });
        Checklist unchanged = world.reload(list.id);
        assertEquals("Groceries", unchanged.title);
        assertNull(unchanged.archivedAt);
    }

    @Test
    void anAnonymousCallerIsUnauthorized() {
        assertThrows(ListException.Unauthorized.class, () -> lists.list(HOUSEHOLD, false));
    }
}
