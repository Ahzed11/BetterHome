package com.betterhome.notifications.directory;

import java.util.Optional;
import java.util.UUID;

/**
 * Boundary to the households service for who a user is. Notifications never reads the households
 * database directly.
 */
public interface UsersGateway {

    /** Our user id and display language ({@code en} or {@code fr}). */
    record UserView(UUID userId, String language) {}

    Optional<UserView> findById(UUID userId);

    Optional<UserView> findByAuthSubject(UUID authSubject);
}
