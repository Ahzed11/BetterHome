package com.betterhome.tasks.service;

import com.betterhome.common.AuthVerifier;
import com.betterhome.tasks.domain.TaskException;
import com.betterhome.tasks.membership.MembershipGateway;
import com.betterhome.tasks.membership.MembershipGateway.MemberView;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.UUID;

@ApplicationScoped
public class CallerService {

    private final AuthVerifier authVerifier;
    private final MembershipGateway membershipGateway;

    @Inject
    public CallerService(AuthVerifier authVerifier, MembershipGateway membershipGateway) {
        this.authVerifier = authVerifier;
        this.membershipGateway = membershipGateway;
    }

    public UUID requireAuthSubject() {
        return authVerifier
                .currentAuthSubject()
                .orElseThrow(() -> new TaskException.Unauthorized("Authentication required"));
    }

    public MemberView requireMember(UUID householdId) {
        UUID subject = requireAuthSubject();
        return membershipGateway
                .findByAuthSubject(householdId, subject)
                .orElseThrow(() -> new TaskException.Forbidden("Not an active household member"));
    }

    public MemberView requireAdmin(UUID householdId) {
        MemberView member = requireMember(householdId);
        if (!member.admin()) {
            throw new TaskException.Forbidden("Admin role required");
        }
        return member;
    }
}
