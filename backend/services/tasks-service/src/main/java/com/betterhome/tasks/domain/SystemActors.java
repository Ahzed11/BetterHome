package com.betterhome.tasks.domain;

import java.util.UUID;

/** Well-known actors for automated lifecycle transitions (spawn / supersede). */
public final class SystemActors {

    /** Used as {@code dismissed_by} when the scheduler closes a task. */
    public static final UUID AUTOMATION =
            UUID.fromString("00000000-0000-4000-8000-000000000001");

    private SystemActors() {}
}
