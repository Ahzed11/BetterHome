package com.betterhome.households.api;

import com.betterhome.households.api.UserDtos.SyncUserRequest;
import com.betterhome.households.api.UserDtos.UserResponse;
import com.betterhome.households.service.CurrentUserService;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/v1/me")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class MeResource {

    private final CurrentUserService currentUserService;

    @Inject
    public MeResource(CurrentUserService currentUserService) {
        this.currentUserService = currentUserService;
    }

    @PUT
    public UserResponse sync(@Valid SyncUserRequest request) {
        return UserResponse.from(
                currentUserService.sync(
                        request.email(),
                        request.givenName(),
                        request.familyName(),
                        request.language(),
                        request.timezone()));
    }

    @GET
    public UserResponse me() {
        return UserResponse.from(currentUserService.requireCurrentUser());
    }
}
