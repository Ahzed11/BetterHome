package com.betterhome.tasks.membership;

import com.betterhome.tasks.domain.TaskException;
import io.quarkus.oidc.client.OidcClientException;
import io.quarkus.oidc.client.Tokens;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.ProcessingException;
import jakarta.ws.rs.WebApplicationException;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Function;
import org.eclipse.microprofile.rest.client.inject.RestClient;

/**
 * Asks households-service about members and settings with this service's own client-credentials
 * token, so request handlers and background jobs behave the same. The caller's identity is already
 * verified by tasks-service before it asks who is a member.
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
                .map(HttpMembershipGateway::toView);
    }

    @Override
    public List<UUID> listEligibleAssigneeIds(UUID householdId) {
        return members(householdId).stream()
                .filter(member -> !member.away())
                .map(HouseholdsClient.Member::userId)
                .toList();
    }

    @Override
    public List<UUID> listActiveMemberIds(UUID householdId) {
        return members(householdId).stream().map(HouseholdsClient.Member::userId).toList();
    }

    @Override
    public HouseholdSettings householdSettings(UUID householdId) {
        HouseholdsClient.Settings settings =
                call(bearer -> households.settings(bearer, householdId))
                        .orElseThrow(() -> new TaskException.NotFound("Household not found"));
        return new HouseholdSettings(
                settings.timezone(), settings.reminderDaysBefore(), settings.reminderTime());
    }

    private List<HouseholdsClient.Member> members(UUID householdId) {
        return call(bearer -> households.members(bearer, householdId)).orElse(List.of());
    }

    private static MemberView toView(HouseholdsClient.Member member) {
        return new MemberView(
                member.userId(),
                member.authSubject(),
                "admin".equals(member.role()),
                member.away(),
                member.joinedAt().toEpochMilli());
    }

    /** Empty when households-service says the household does not exist. */
    private <T> Optional<T> call(Function<String, T> request) {
        try {
            return Optional.of(request.apply("Bearer " + tokens.getAccessToken()));
        } catch (WebApplicationException e) {
            if (e.getResponse().getStatus() == 404) {
                return Optional.empty();
            }
            throw new TaskException.ServiceUnavailable(
                    "households-service answered " + e.getResponse().getStatus());
        } catch (ProcessingException | OidcClientException e) {
            throw new TaskException.ServiceUnavailable("households-service is unreachable");
        }
    }
}
