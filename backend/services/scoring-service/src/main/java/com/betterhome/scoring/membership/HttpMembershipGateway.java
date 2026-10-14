package com.betterhome.scoring.membership;

import com.betterhome.scoring.domain.ScoringException;
import io.quarkus.oidc.client.OidcClientException;
import io.quarkus.oidc.client.Tokens;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.ProcessingException;
import jakarta.ws.rs.WebApplicationException;
import java.time.DateTimeException;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.eclipse.microprofile.rest.client.inject.RestClient;

/**
 * Asks households-service about members with this service's own client-credentials token. The
 * caller's identity is already verified by scoring-service before it asks who is a member.
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
        return listActiveMembers(householdId).stream()
                .filter(member -> member.authSubject().equals(authSubject))
                .findFirst();
    }

    @Override
    public List<MemberView> listActiveMembers(UUID householdId) {
        return members(householdId).stream().map(HttpMembershipGateway::toView).toList();
    }

    @Override
    public ZoneId householdZone(UUID householdId) {
        try {
            String timezone =
                    households
                            .settings("Bearer " + tokens.getAccessToken(), householdId)
                            .timezone();
            return timezone == null ? ZoneOffset.UTC : ZoneId.of(timezone);
        } catch (DateTimeException e) {
            return ZoneOffset.UTC;
        } catch (WebApplicationException e) {
            if (e.getResponse().getStatus() == 404) {
                return ZoneOffset.UTC;
            }
            throw new ScoringException.ServiceUnavailable(
                    "households-service answered " + e.getResponse().getStatus());
        } catch (ProcessingException | OidcClientException e) {
            throw new ScoringException.ServiceUnavailable("households-service is unreachable");
        }
    }

    private List<HouseholdsClient.Member> members(UUID householdId) {
        try {
            return households.members("Bearer " + tokens.getAccessToken(), householdId);
        } catch (WebApplicationException e) {
            if (e.getResponse().getStatus() == 404) {
                return List.of();
            }
            throw new ScoringException.ServiceUnavailable(
                    "households-service answered " + e.getResponse().getStatus());
        } catch (ProcessingException | OidcClientException e) {
            throw new ScoringException.ServiceUnavailable("households-service is unreachable");
        }
    }

    private static MemberView toView(HouseholdsClient.Member member) {
        return new MemberView(
                member.userId(),
                member.authSubject(),
                "admin".equals(member.role()),
                member.away(),
                member.joinedAt().toEpochMilli());
    }
}
