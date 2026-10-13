package com.betterhome.tasks.domain;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class RoundRobinTest {

    private static final UUID A = UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
    private static final UUID B = UUID.fromString("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb");
    private static final UUID C = UUID.fromString("cccccccc-cccc-cccc-cccc-cccccccccccc");

    @Test
    void picksFirstWhenCursorNull() {
        assertEquals(A, RoundRobin.next(List.of(A, B, C), null).orElseThrow());
    }

    @Test
    void wrapsAfterLast() {
        assertEquals(A, RoundRobin.next(List.of(A, B, C), C).orElseThrow());
    }

    @Test
    void skipsMissingCursorByRestarting() {
        UUID unknown = UUID.fromString("dddddddd-dddd-dddd-dddd-dddddddddddd");
        assertEquals(A, RoundRobin.next(List.of(A, B), unknown).orElseThrow());
    }

    @Test
    void emptyWhenNobodyEligible() {
        assertTrue(RoundRobin.next(List.of(), A).isEmpty());
    }
}
