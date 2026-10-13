package com.betterhome.households.service;

import com.betterhome.common.AuthVerifier;
import com.betterhome.common.Clock;
import com.betterhome.households.domain.AppUser;
import com.betterhome.households.domain.HouseholdException;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.util.Locale;
import java.util.UUID;

@ApplicationScoped
public class CurrentUserService {

    private final AuthVerifier authVerifier;
    private final Clock clock;

    @Inject
    public CurrentUserService(AuthVerifier authVerifier, Clock clock) {
        this.authVerifier = authVerifier;
        this.clock = clock;
    }

    public UUID requireAuthSubject() {
        return authVerifier
                .currentAuthSubject()
                .orElseThrow(() -> new HouseholdException.Unauthorized("Authentication required"));
    }

    public AppUser requireCurrentUser() {
        UUID subject = requireAuthSubject();
        return AppUser.findByAuthSubject(subject)
                .orElseThrow(
                        () ->
                                new HouseholdException.NotFound(
                                        "User profile not synced; call PUT /v1/me first"));
    }

    @Transactional
    public AppUser sync(
            String email,
            String givenName,
            String familyName,
            String language,
            String timezone) {
        UUID subject = requireAuthSubject();
        Instant now = clock.now();
        String normalizedEmail = normalizeEmail(email);
        AppUser user = AppUser.findByAuthSubject(subject).orElse(null);
        if (user == null) {
            user = new AppUser();
            user.id = UUID.randomUUID();
            user.authSubject = subject;
            user.createdAt = now;
            user.email = normalizedEmail;
            user.givenName = givenName == null ? "" : givenName.trim();
            user.familyName = familyName == null ? "" : familyName.trim();
            user.language = normalizeLanguage(language);
            user.timezone = timezone == null || timezone.isBlank() ? "UTC" : timezone.trim();
            user.updatedAt = now;
            user.persist();
            return user;
        }
        user.email = normalizedEmail;
        user.givenName = givenName == null ? "" : givenName.trim();
        user.familyName = familyName == null ? "" : familyName.trim();
        user.language = normalizeLanguage(language);
        user.timezone = timezone == null || timezone.isBlank() ? "UTC" : timezone.trim();
        user.updatedAt = now;
        user.deletedAt = null;
        return user;
    }

    private static String normalizeEmail(String email) {
        if (email == null || email.isBlank()) {
            throw new HouseholdException.BadRequest("email is required");
        }
        return email.trim().toLowerCase(Locale.ROOT);
    }

    private static String normalizeLanguage(String language) {
        if (language == null || language.isBlank()) {
            return "en";
        }
        String normalized = language.trim().toLowerCase(Locale.ROOT);
        if (!normalized.equals("en") && !normalized.equals("fr")) {
            throw new HouseholdException.BadRequest("language must be en or fr");
        }
        return normalized;
    }
}
