package com.betterhome.scoring.domain;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;
import java.io.Serializable;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

@Entity
@Table(name = "monthly_recap_celebration")
@IdClass(MonthlyRecapCelebration.Pk.class)
public class MonthlyRecapCelebration extends PanacheEntityBase {

    @Id
    @Column(name = "recap_id", nullable = false)
    public UUID recapId;

    @Id
    @Column(name = "user_id", nullable = false)
    public UUID userId;

    @Column(name = "seen_at", nullable = false)
    public Instant seenAt;

    public static boolean hasSeen(UUID recapId, UUID userId) {
        return count("recapId = ?1 and userId = ?2", recapId, userId) > 0;
    }

    public static final class Pk implements Serializable {
        public UUID recapId;
        public UUID userId;

        public Pk() {}

        public Pk(UUID recapId, UUID userId) {
            this.recapId = recapId;
            this.userId = userId;
        }

        @Override
        public boolean equals(Object o) {
            if (this == o) {
                return true;
            }
            if (!(o instanceof Pk pk)) {
                return false;
            }
            return Objects.equals(recapId, pk.recapId) && Objects.equals(userId, pk.userId);
        }

        @Override
        public int hashCode() {
            return Objects.hash(recapId, userId);
        }
    }
}
