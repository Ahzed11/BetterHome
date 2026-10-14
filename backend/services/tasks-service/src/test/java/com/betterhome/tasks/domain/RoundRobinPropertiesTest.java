package com.betterhome.tasks.domain;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import net.jqwik.api.Arbitraries;
import net.jqwik.api.Arbitrary;
import net.jqwik.api.ForAll;
import net.jqwik.api.Property;
import net.jqwik.api.Provide;
import net.jqwik.api.constraints.IntRange;

/**
 * Round robin must hold for every roster, not only the examples of {@link RoundRobinTest}: it never
 * picks someone who is not eligible, and while the roster is stable everybody gets a turn before
 * anybody gets a second one.
 */
class RoundRobinPropertiesTest {

    private static UUID user(int n) {
        return new UUID(0, n);
    }

    @Provide
    Arbitrary<List<UUID>> roster() {
        return Arbitraries.integers()
                .between(1, 500)
                .list()
                .uniqueElements()
                .ofMaxSize(12)
                .map(ids -> ids.stream().map(RoundRobinPropertiesTest::user).toList());
    }

    @Provide
    Arbitrary<List<UUID>> nonEmptyRoster() {
        return Arbitraries.integers()
                .between(1, 500)
                .list()
                .uniqueElements()
                .ofMinSize(1)
                .ofMaxSize(12)
                .map(ids -> ids.stream().map(RoundRobinPropertiesTest::user).toList());
    }

    @Property
    void theNextAssigneeIsAlwaysOneOfTheEligibleMembers(
            @ForAll("roster") List<UUID> eligible,
            @ForAll @IntRange(min = -1, max = 40) int cursorIndex,
            @ForAll boolean cursorIsStranger) {
        UUID cursor;
        if (cursorIsStranger) {
            cursor = user(10_000);
        } else if (eligible.isEmpty() || cursorIndex < 0) {
            cursor = null;
        } else {
            cursor = eligible.get(cursorIndex % eligible.size());
        }

        Optional<UUID> next = RoundRobin.next(eligible, cursor);

        assertEquals(!eligible.isEmpty(), next.isPresent());
        next.ifPresent(picked -> assertTrue(eligible.contains(picked)));
    }

    @Property
    void nobodyEligibleMeansNobodyIsPicked(@ForAll @IntRange(min = 0, max = 50) int cursor) {
        assertTrue(RoundRobin.next(List.of(), user(cursor)).isEmpty());
        assertTrue(RoundRobin.next(null, user(cursor)).isEmpty());
    }

    @Property
    void everyoneGetsTheirTurnBeforeAnyoneGetsASecondOne(
            @ForAll("nonEmptyRoster") List<UUID> eligible,
            @ForAll @IntRange(min = 1, max = 5) int cycles) {
        List<UUID> picks = new ArrayList<>();
        UUID cursor = null;
        for (int i = 0; i < eligible.size() * cycles; i++) {
            cursor = RoundRobin.next(eligible, cursor).orElseThrow();
            picks.add(cursor);
        }

        Map<UUID, Integer> counts = new HashMap<>();
        picks.forEach(p -> counts.merge(p, 1, Integer::sum));
        assertEquals(eligible.size(), counts.size(), "everybody was picked");
        assertTrue(counts.values().stream().allMatch(c -> c == cycles), "equally often: " + counts);
        for (int start = 0; start + eligible.size() <= picks.size(); start += eligible.size()) {
            Set<UUID> window = new HashSet<>(picks.subList(start, start + eligible.size()));
            assertEquals(eligible.size(), window.size(), "a full turn has no repeat");
        }
        assertEquals(eligible, picks.subList(0, eligible.size()), "in the roster's order");
    }

    @Property
    void theSamePersonIsNeverPickedTwiceInARowWhenThereIsAChoice(
            @ForAll("nonEmptyRoster") List<UUID> eligible,
            @ForAll @IntRange(min = 0, max = 30) int steps) {
        UUID cursor = null;
        for (int i = 0; i < steps; i++) {
            UUID next = RoundRobin.next(eligible, cursor).orElseThrow();
            if (eligible.size() > 1 && cursor != null) {
                assertNotEquals(cursor, next);
            }
            cursor = next;
        }
    }

    @Property
    void aRosterThatChangesEveryRoundNeverYieldsAnIneligibleMember(
            @ForAll("nonEmptyRoster") List<UUID> everyone, @ForAll("rounds") List<Long> awayMasks) {
        UUID cursor = null;
        for (long mask : awayMasks) {
            List<UUID> eligible = new ArrayList<>();
            for (int i = 0; i < everyone.size(); i++) {
                boolean away = (mask >> i & 1L) == 1L;
                if (!away) {
                    eligible.add(everyone.get(i));
                }
            }

            Optional<UUID> next = RoundRobin.next(eligible, cursor);

            if (eligible.isEmpty()) {
                assertTrue(next.isEmpty(), "everybody away: nobody available");
                continue;
            }
            assertTrue(eligible.contains(next.orElseThrow()), "picked someone who is away");
            if (cursor != null && eligible.contains(cursor) && eligible.size() > 1) {
                int after = (eligible.indexOf(cursor) + 1) % eligible.size();
                assertEquals(eligible.get(after), next.get(), "the member after the cursor");
            }
            cursor = next.get();
        }
    }

    @Provide
    Arbitrary<List<Long>> rounds() {
        return Arbitraries.longs().between(0, (1L << 12) - 1).list().ofMaxSize(40);
    }

    @Property
    void aCursorWhoIsNoLongerEligibleRestartsAtTheFirstMember(
            @ForAll("nonEmptyRoster") List<UUID> eligible) {
        UUID gone = user(9_999);

        assertFalse(eligible.contains(gone));
        assertEquals(eligible.getFirst(), RoundRobin.next(eligible, gone).orElseThrow());
        assertEquals(eligible.getFirst(), RoundRobin.next(eligible, null).orElseThrow());
    }
}
