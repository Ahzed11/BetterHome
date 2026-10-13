package com.betterhome.households.domain;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Instant;
import org.junit.jupiter.api.Test;

class MembershipAwayTest {

    @Test
    void awayWindowRespectsFromAndUntil() {
        Membership membership = new Membership();
        membership.awayFrom = Instant.parse("2026-06-01T00:00:00Z");
        membership.awayUntil = Instant.parse("2026-06-10T00:00:00Z");

        assertFalse(membership.isAway(Instant.parse("2026-05-31T23:59:59Z")));
        assertTrue(membership.isAway(Instant.parse("2026-06-01T00:00:00Z")));
        assertTrue(membership.isAway(Instant.parse("2026-06-05T12:00:00Z")));
        assertTrue(membership.isAway(Instant.parse("2026-06-10T00:00:00Z")));
        assertFalse(membership.isAway(Instant.parse("2026-06-10T00:00:01Z")));
    }

    @Test
    void openEndedAwayHasNoUntil() {
        Membership membership = new Membership();
        membership.awayFrom = Instant.parse("2026-06-01T00:00:00Z");
        assertTrue(membership.isAway(Instant.parse("2026-12-01T00:00:00Z")));
    }
}
