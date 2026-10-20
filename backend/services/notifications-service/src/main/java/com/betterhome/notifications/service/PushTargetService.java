package com.betterhome.notifications.service;

import com.betterhome.common.Clock;
import com.betterhome.notifications.domain.PushTarget;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Optional;
import java.util.UUID;

/** The Gotify application token of each user, the only place a push can be sent to (ADR 0027). */
@ApplicationScoped
public class PushTargetService {

    /** What the API may say about a target: never the token. */
    public record Registration(Instant registeredAt) {}

    private final Clock clock;

    @Inject
    public PushTargetService(Clock clock) {
        this.clock = clock;
    }

    /** Registers the token, replacing the one the user had. */
    @Transactional
    public Registration register(UUID userId, String token) {
        Instant now = clock.now().truncatedTo(ChronoUnit.MICROS);
        PushTarget target = PushTarget.forUser(userId).orElseGet(() -> newTarget(userId, now));
        target.token = token;
        target.updatedAt = now;
        target.persist();
        return new Registration(target.createdAt);
    }

    @Transactional
    public Optional<Registration> find(UUID userId) {
        return PushTarget.forUser(userId).map(target -> new Registration(target.createdAt));
    }

    /** True when there was a target to remove. */
    @Transactional
    public boolean remove(UUID userId) {
        return PushTarget.deleteById(userId);
    }

    /** The token to send to, if the user registered one. */
    @Transactional
    public Optional<String> tokenOf(UUID userId) {
        return PushTarget.forUser(userId).map(target -> target.token);
    }

    /**
     * Drops a token Gotify refused. Only that token is removed: if the user registered a new one
     * meanwhile, it stays.
     */
    @Transactional
    public boolean removeRefused(UUID userId, String token) {
        return PushTarget.delete("userId = ?1 and token = ?2", userId, token) > 0;
    }

    private static PushTarget newTarget(UUID userId, Instant now) {
        PushTarget target = new PushTarget();
        target.userId = userId;
        target.createdAt = now;
        return target;
    }
}
