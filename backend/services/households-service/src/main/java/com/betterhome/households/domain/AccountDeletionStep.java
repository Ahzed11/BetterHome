package com.betterhome.households.domain;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;
import java.io.Serializable;
import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

/** A target (for example {@code tasks}) that confirmed it dealt with a deleted account. */
@Entity
@Table(name = "account_deletion_step")
@IdClass(AccountDeletionStep.Pk.class)
public class AccountDeletionStep extends PanacheEntityBase {

    @Id
    @Column(name = "user_id", nullable = false)
    public UUID userId;

    @Id
    @Column(nullable = false)
    public String target;

    @Column(name = "done_at", nullable = false)
    public Instant doneAt;

    public static AccountDeletionStep done(UUID userId, String target, Instant now) {
        AccountDeletionStep step = new AccountDeletionStep();
        step.userId = userId;
        step.target = target;
        step.doneAt = now;
        return step;
    }

    /** The names of the targets that already confirmed for this user. */
    public static Set<String> doneTargets(UUID userId) {
        List<AccountDeletionStep> steps = list("userId", userId);
        return steps.stream().map(step -> step.target).collect(Collectors.toSet());
    }

    public static final class Pk implements Serializable {
        public UUID userId;
        public String target;

        public Pk() {}

        public Pk(UUID userId, String target) {
            this.userId = userId;
            this.target = target;
        }

        @Override
        public boolean equals(Object o) {
            if (this == o) {
                return true;
            }
            if (!(o instanceof Pk pk)) {
                return false;
            }
            return Objects.equals(userId, pk.userId) && Objects.equals(target, pk.target);
        }

        @Override
        public int hashCode() {
            return Objects.hash(userId, target);
        }
    }
}
