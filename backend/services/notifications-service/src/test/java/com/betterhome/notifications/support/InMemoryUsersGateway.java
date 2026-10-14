package com.betterhome.notifications.support;

import com.betterhome.notifications.directory.HttpUsersGateway;
import com.betterhome.notifications.directory.UsersGateway;
import com.betterhome.notifications.domain.NotificationException;
import jakarta.annotation.Priority;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Alternative;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-process user directory that stands in for {@link HttpUsersGateway} in Quarkus tests, so domain
 * tests do not need a households server.
 */
@Alternative
@Priority(1)
@ApplicationScoped
public class InMemoryUsersGateway implements UsersGateway {

    private final Map<UUID, UserView> byId = new ConcurrentHashMap<>();
    private final Map<UUID, UserView> bySubject = new ConcurrentHashMap<>();
    private volatile boolean unavailable;

    public void add(UUID authSubject, UUID userId, String language) {
        UserView view = new UserView(userId, language);
        byId.put(userId, view);
        bySubject.put(authSubject, view);
    }

    /** Makes every following lookup fail as an unreachable households-service would. */
    public void setUnavailable(boolean unavailable) {
        this.unavailable = unavailable;
    }

    public void clear() {
        unavailable = false;
        byId.clear();
        bySubject.clear();
    }

    @Override
    public Optional<UserView> findById(UUID userId) {
        requireAvailable();
        return Optional.ofNullable(byId.get(userId));
    }

    @Override
    public Optional<UserView> findByAuthSubject(UUID authSubject) {
        requireAvailable();
        return Optional.ofNullable(bySubject.get(authSubject));
    }

    private void requireAvailable() {
        if (unavailable) {
            throw new NotificationException.ServiceUnavailable("households-service is unreachable");
        }
    }
}
