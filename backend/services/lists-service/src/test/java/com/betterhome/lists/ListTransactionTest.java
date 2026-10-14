package com.betterhome.lists;

import static com.betterhome.lists.TestWorld.ADMIN_SUBJECT;
import static com.betterhome.lists.TestWorld.HOUSEHOLD;
import static com.betterhome.lists.TestWorld.MEMBER_SUBJECT;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.lists.domain.Checklist;
import com.betterhome.lists.domain.ChecklistItem;
import com.betterhome.lists.domain.ListException;
import com.betterhome.lists.service.ChecklistService;
import com.betterhome.lists.service.ItemService;
import io.quarkus.arc.Arc;
import io.quarkus.arc.ManagedContext;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.transaction.UserTransaction;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.stream.IntStream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class ListTransactionTest {

    private static final Instant T0 = Instant.parse("2026-03-01T10:00:00Z");

    @Inject TestWorld world;
    @Inject FixedClock clock;
    @Inject ChecklistService lists;
    @Inject ItemService items;
    @Inject UserTransaction transaction;

    @BeforeEach
    void seed() {
        world.reset();
        clock.set(T0);
    }

    @Test
    void aResetThatDoesNotCommitLeavesEveryItemChecked() throws Exception {
        Checklist list = world.seedList(HOUSEHOLD, "Packing", T0);
        ChecklistItem socks = world.seedItem(list.id, "Socks", 0, T0);
        ChecklistItem shoes = world.seedItem(list.id, "Shoes", 1, T0);
        world.runAs(
                MEMBER_SUBJECT,
                () -> {
                    items.check(HOUSEHOLD, list.id, socks.id);
                    items.check(HOUSEHOLD, list.id, shoes.id);
                });

        transaction.begin();
        try {
            world.runAs(ADMIN_SUBJECT, () -> items.reset(HOUSEHOLD, list.id));
        } finally {
            transaction.rollback();
        }

        assertTrue(world.reloadItem(socks.id).isChecked());
        assertTrue(world.reloadItem(shoes.id).isChecked());
    }

    @Test
    void aRejectedResetLeavesNoPartialStateOnAnArchivedList() {
        Checklist list = world.seedList(HOUSEHOLD, "Old", T0);
        ChecklistItem socks = world.seedItem(list.id, "Socks", 0, T0);
        world.runAs(MEMBER_SUBJECT, () -> items.check(HOUSEHOLD, list.id, socks.id));
        world.archive(list.id, T0);

        world.runAs(
                MEMBER_SUBJECT,
                () ->
                        assertThrows(
                                ListException.Conflict.class,
                                () -> items.reset(HOUSEHOLD, list.id)));

        assertTrue(world.reloadItem(socks.id).isChecked());
    }

    @Test
    void anInvalidItemOrListCreatesNoRow() {
        Checklist list = world.seedList(HOUSEHOLD, "Groceries", T0);

        world.runAs(
                ADMIN_SUBJECT,
                () -> {
                    assertThrows(ListException.BadRequest.class, () -> lists.create(HOUSEHOLD, ""));
                    assertThrows(
                            ListException.BadRequest.class,
                            () -> items.add(HOUSEHOLD, list.id, " "));
                });

        assertEquals(1, Checklist.count());
        assertEquals(0, ChecklistItem.count());
    }

    @Test
    void concurrentAddsGetDistinctPositions() throws Exception {
        Checklist list = world.seedList(HOUSEHOLD, "Groceries", T0);
        int adds = 8;
        ExecutorService pool = Executors.newFixedThreadPool(adds);
        try {
            List<Future<Integer>> results =
                    IntStream.range(0, adds)
                            .mapToObj(n -> pool.submit(() -> addInOwnRequest(list.id, "Item " + n)))
                            .toList();
            for (Future<Integer> result : results) {
                result.get();
            }
        } finally {
            pool.shutdownNow();
        }

        List<ChecklistItem> stored =
                world.asUser(ADMIN_SUBJECT, () -> items.list(HOUSEHOLD, list.id));
        assertEquals(
                IntStream.range(0, adds).boxed().toList(),
                stored.stream().map(i -> i.position).toList());
    }

    private int addInOwnRequest(UUID listId, String title) {
        ManagedContext requestContext = Arc.container().requestContext();
        requestContext.activate();
        try {
            return world.asUser(MEMBER_SUBJECT, () -> items.add(HOUSEHOLD, listId, title)).position;
        } finally {
            requestContext.terminate();
        }
    }
}
