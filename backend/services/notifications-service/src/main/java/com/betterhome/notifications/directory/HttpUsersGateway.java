package com.betterhome.notifications.directory;

import com.betterhome.notifications.domain.NotificationException;
import io.quarkus.oidc.client.OidcClientException;
import io.quarkus.oidc.client.Tokens;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.ProcessingException;
import jakarta.ws.rs.WebApplicationException;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Function;
import org.eclipse.microprofile.rest.client.inject.RestClient;

/**
 * Asks households-service about users with this service's own client-credentials token. An outage
 * is reported as unavailable, never as "no such user".
 */
@ApplicationScoped
public class HttpUsersGateway implements UsersGateway {

    private final UsersClient users;
    private final Tokens tokens;

    @Inject
    public HttpUsersGateway(@RestClient UsersClient users, Tokens tokens) {
        this.users = users;
        this.tokens = tokens;
    }

    @Override
    public Optional<UserView> findById(UUID userId) {
        return lookup(bearer -> users.byId(bearer, userId));
    }

    @Override
    public Optional<UserView> findByAuthSubject(UUID authSubject) {
        return lookup(bearer -> users.bySubject(bearer, authSubject));
    }

    private Optional<UserView> lookup(Function<String, UsersClient.User> call) {
        try {
            UsersClient.User user = call.apply("Bearer " + tokens.getAccessToken());
            return Optional.of(new UserView(user.userId(), user.language()));
        } catch (WebApplicationException e) {
            if (e.getResponse().getStatus() == 404) {
                return Optional.empty();
            }
            throw new NotificationException.ServiceUnavailable(
                    "households-service answered " + e.getResponse().getStatus());
        } catch (ProcessingException | OidcClientException e) {
            throw new NotificationException.ServiceUnavailable("households-service is unreachable");
        }
    }
}
