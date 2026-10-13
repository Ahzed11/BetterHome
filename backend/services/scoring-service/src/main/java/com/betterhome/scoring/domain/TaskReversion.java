package com.betterhome.scoring.domain;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "task_reversion")
public class TaskReversion extends PanacheEntityBase {

    @Id public UUID id;

    @Column(name = "household_id", nullable = false)
    public UUID householdId;

    @Column(name = "task_id", nullable = false)
    public UUID taskId;

    @Column(name = "admin_user_id", nullable = false)
    public UUID adminUserId;

    @Column(nullable = false)
    public String reason;

    @Column(name = "points_reversed", nullable = false)
    public int pointsReversed;

    @Enumerated(EnumType.STRING)
    @Column(name = "resulting_status", nullable = false)
    public ReversionResultingStatus resultingStatus;

    @Column(name = "created_at", nullable = false)
    public Instant createdAt;
}
