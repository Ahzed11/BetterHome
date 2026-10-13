package com.betterhome.lists.membership;

import com.betterhome.lists.domain.ListException;
import io.quarkus.oidc.client.OidcClientException;
import io.quarkus.oidc.client.Tokens;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.ProcessingException;
import jakarta.ws.rs.WebApplicationException;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.eclipse.microprofile.rest.client.inject.RestClient;

/**
 * Asks households-service about members with this service's own client-credentials token. The
 * caller's identity is already verified by lists-service before it asks who is a member.
 */
@ApplicationScoped
public class HttpMembershipGateway implements MembershipGateway {

    private final HouseholdsClient households;
    private final Tokens tokens;

    @Inject
    public HttpMembershipGateway(@RestClient HouseholdsClient households, Tokens tokens) {
        this.households = households;
        this.tokens = tokens;
    }

    @Override
    public Optional<MemberView> findByAuthSubject(UUID householdId, UUID authSubject) {
        return members(householdId).stream()
                .filter(member -> member.authSubject().equals(authSubject))
                .findFirst()
                .map(
                        member ->
                                new MemberView(
                                        member.userId(),
                                        member.authSubject(),
                                        "admin".equals(member.role())));
    }

    /** Empty when households-service says the household does not exist. */
    private List<HouseholdsClient.Member> members(UUID householdId) {
        try {
            return households.members("Bearer " + tokens.getAccessToken(), householdId);
        } catch (WebApplicationException e) {
            if (e.getResponse().getStatus() == 404) {
                return List.of();
            }
            throw new ListException.ServiceUnavailable(
                    "households-service answered " + e.getResponse().getStatus());
        } catch (ProcessingException | OidcClientException e) {
            throw new ListException.ServiceUnavailable("households-service is unreachable");
        }
    }
}
