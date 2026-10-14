package com.betterhome.scoring.domain;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.math.BigInteger;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import net.jqwik.api.Arbitraries;
import net.jqwik.api.Arbitrary;
import net.jqwik.api.ForAll;
import net.jqwik.api.Property;
import net.jqwik.api.Provide;
import net.jqwik.api.constraints.IntRange;
import net.jqwik.api.stateful.Action;
import net.jqwik.api.stateful.ActionSequence;

/**
 * The ledger rules hold for every input, and any order of awards, reversals and adjustments keeps
 * the ledger's books straight (AGENTS 5.1: ledger sum equals awarded minus reversed, scores never
 * go negative).
 */
class LedgerRulesPropertiesTest {

    @Property
    void aReversalIsAllowedExactlyWhenItIsPositiveAndWithinWhatRemainsOnTheTask(
            @ForAll int netForTask, @ForAll int pointsToReverse) {
        boolean expected = pointsToReverse > 0 && netForTask >= pointsToReverse;

        assertEquals(expected, LedgerRules.canReverse(netForTask, pointsToReverse));
    }

    @Property
    void aReversalNeverTakesMoreThanTheTaskHas(
            @ForAll int netForTask, @ForAll int pointsToReverse) {
        if (LedgerRules.canReverse(netForTask, pointsToReverse)) {
            assertTrue((long) netForTask - pointsToReverse >= 0, "the task would go below zero");
        }
    }

    @Property
    void anAdjustmentIsAllowedExactlyWhenTheSumStaysAtZeroOrMoreEvenForExtremeValues(
            @ForAll int currentSum, @ForAll int delta) {
        boolean expected =
                BigInteger.valueOf(currentSum).add(BigInteger.valueOf(delta)).signum() >= 0;

        assertEquals(expected, LedgerRules.adjustmentKeepsScoreNonNegative(currentSum, delta));
    }

    @Property
    void aScoreIsNeverBelowZeroAndEqualsTheSumWhenTheSumIsNotNegative(@ForAll int ledgerSum) {
        int score = LedgerRules.score(ledgerSum);

        assertTrue(score >= 0);
        if (ledgerSum >= 0) {
            assertEquals(ledgerSum, score);
        }
    }

    // ---- stateful: any order of operations ----

    /** The ledger as a list of rows, changed only through the rules the service uses. */
    static final class Ledger {
        record Row(int user, int task, int points, String kind) {}

        final List<Row> rows = new ArrayList<>();
        final Map<Integer, Integer> ownerOfTask = new HashMap<>();

        int awarded;
        int reversed;
        int adjusted;

        int net(int task) {
            return rows.stream().filter(r -> r.task() == task).mapToInt(Row::points).sum();
        }

        int sum(int user) {
            return rows.stream().filter(r -> r.user() == user).mapToInt(Row::points).sum();
        }

        /** The same decision as LedgerService.award: a task completion is awarded once. */
        boolean award(int user, int task, int points) {
            if (ownerOfTask.containsKey(task)) {
                return false;
            }
            ownerOfTask.put(task, user);
            rows.add(new Row(user, task, points, "award"));
            awarded += points;
            return true;
        }

        /** The same decision as LedgerService.reverse. */
        boolean reverse(int task, int points) {
            Integer owner = ownerOfTask.get(task);
            if (owner == null || !LedgerRules.canReverse(net(task), points)) {
                return false;
            }
            rows.add(new Row(owner, task, -points, "reversal"));
            reversed += points;
            return true;
        }

        /** The same decision as LedgerService.adjust. */
        boolean adjust(int user, int delta) {
            if (delta == 0 || !LedgerRules.adjustmentKeepsScoreNonNegative(sum(user), delta)) {
                return false;
            }
            rows.add(new Row(user, -1, delta, "adjust"));
            adjusted += delta;
            return true;
        }
    }

    @Provide
    Arbitrary<ActionSequence<Ledger>> ledgerActions() {
        Arbitrary<Action<Ledger>> actions =
                Arbitraries.oneOf(
                        Arbitraries.integers()
                                .between(0, 3)
                                .flatMap(
                                        user ->
                                                Arbitraries.integers()
                                                        .between(0, 5)
                                                        .flatMap(
                                                                task ->
                                                                        Arbitraries.integers()
                                                                                .between(1, 20)
                                                                                .map(
                                                                                        points ->
                                                                                                award(
                                                                                                        user,
                                                                                                        task,
                                                                                                        points)))),
                        Arbitraries.integers()
                                .between(0, 5)
                                .flatMap(
                                        task ->
                                                Arbitraries.integers()
                                                        .between(-3, 25)
                                                        .map(points -> reverse(task, points))),
                        Arbitraries.integers()
                                .between(0, 3)
                                .flatMap(
                                        user ->
                                                Arbitraries.integers()
                                                        .between(-25, 25)
                                                        .map(delta -> adjust(user, delta))));
        return Arbitraries.sequences(actions);
    }

    private static Action<Ledger> award(int user, int task, int points) {
        return state -> {
            state.award(user, task, points);
            return state;
        };
    }

    private static Action<Ledger> reverse(int task, int points) {
        return state -> {
            state.reverse(task, points);
            return state;
        };
    }

    private static Action<Ledger> adjust(int user, int delta) {
        return state -> {
            state.adjust(user, delta);
            return state;
        };
    }

    @Property
    void anyOrderOfOperationsKeepsTheBooksStraight(
            @ForAll("ledgerActions") ActionSequence<Ledger> actions) {
        actions.withInvariant(
                        "the rows add up to awarded - reversed + adjusted",
                        ledger -> {
                            int total = ledger.rows.stream().mapToInt(Ledger.Row::points).sum();
                            assertEquals(ledger.awarded - ledger.reversed + ledger.adjusted, total);
                        })
                .withInvariant(
                        "a task never has more reversed than awarded",
                        ledger -> {
                            for (int task : ledger.ownerOfTask.keySet()) {
                                assertTrue(ledger.net(task) >= 0, "task " + task + " below zero");
                            }
                        })
                .withInvariant(
                        "no score shown is below zero, and none is shown as more than the ledger holds",
                        ledger -> {
                            for (int user = 0; user <= 3; user++) {
                                int shown = LedgerRules.score(ledger.sum(user));
                                assertTrue(shown >= 0);
                                assertTrue(shown >= ledger.sum(user));
                            }
                        })
                .run(new Ledger());
    }

    @Property
    void aRefusedOperationLeavesTheLedgerUnchanged(
            @ForAll @IntRange(min = 1, max = 30) int points,
            @ForAll @IntRange(min = 1, max = 30) int extra) {
        Ledger ledger = new Ledger();
        ledger.award(0, 1, points);
        List<Ledger.Row> before = new ArrayList<>(ledger.rows);

        boolean reversed = ledger.reverse(1, points + extra);
        boolean adjusted = ledger.adjust(0, -(points + extra));

        assertEquals(false, reversed);
        assertEquals(false, adjusted);
        assertEquals(before, ledger.rows);
    }
}
