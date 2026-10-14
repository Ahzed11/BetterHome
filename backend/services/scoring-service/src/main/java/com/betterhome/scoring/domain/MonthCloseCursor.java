package com.betterhome.scoring.domain;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/** Where the monthly close of one household stands. */
@Entity
@Table(name = "month_close_cursor")
public class MonthCloseCursor extends PanacheEntityBase {

    @Id
    @Column(name = "household_id")
    public UUID householdId;

    /** The next month to close, {@code YYYY-MM}. */
    @Column(name = "next_month", nullable = false, length = 7)
    public String nextMonth;

    /** Not before this instant: the end of that month locally, or a retry time after a failure. */
    @Column(name = "next_close_at", nullable = false)
    public Instant nextCloseAt;

    @Column(name = "updated_at", nullable = false)
    public Instant updatedAt;
}
