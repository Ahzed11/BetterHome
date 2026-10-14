package com.betterhome.notifications.service;

import com.betterhome.common.AuthVerifier;
import com.betterhome.notifications.directory.UsersGateway;
import com.betterhome.notifications.domain.NotificationException;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.UUID;

/** Maps the verified token subject to our user id, the only identity notifications are tied to. */
@ApplicationScoped
public class CallerService {

    private final AuthVerifier authVerifier;
    private final UsersGateway users;

    @Inject
    public CallerService(AuthVerifier authVerifier, UsersGateway users) {
        this.authVerifier = authVerifier;
        this.users = users;
    }

    public UUID requireUserId() {
        UUID subject =
                authVerifier
                        .currentAuthSubject()
                        .orElseThrow(
                                () ->
                                        new NotificationException.Unauthorized(
                                                "Authentication required"));
        return users.findByAuthSubject(subject)
                .map(UsersGateway.UserView::userId)
                .orElseThrow(() -> new NotificationException.Forbidden("No profile for this user"));
    }
}
