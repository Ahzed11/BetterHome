package com.betterhome.scoring.domain;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Entity
@Table(name = "monthly_recap")
public class MonthlyRecap extends PanacheEntityBase {

    @Id public UUID id;

    @Column(name = "household_id", nullable = false)
    public UUID householdId;

    @Column(name = "year_month", nullable = false, length = 7)
    public String yearMonth;

    @Column(name = "winner_user_id")
    public UUID winnerUserId;

    @Column(name = "winner_points", nullable = false)
    public int winnerPoints;

    @Column(name = "total_points", nullable = false)
    public int totalPoints;

    @Column(name = "created_at", nullable = false)
    public Instant createdAt;

    public static Optional<MonthlyRecap> findByHouseholdAndMonth(
            UUID householdId, String yearMonth) {
        return find("householdId = ?1 and yearMonth = ?2", householdId, yearMonth)
                .firstResultOptional();
    }

    public static List<MonthlyRecap> listForHousehold(UUID householdId) {
        return list("householdId = ?1 order by yearMonth desc", householdId);
    }
}
