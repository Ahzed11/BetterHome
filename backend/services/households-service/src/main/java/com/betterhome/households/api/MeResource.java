package com.betterhome.households.api;

import com.betterhome.households.api.UserDtos.SyncUserRequest;
import com.betterhome.households.api.UserDtos.UserResponse;
import com.betterhome.households.service.AccountDeletionService;
import com.betterhome.households.service.CurrentUserService;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

@Path("/v1/me")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "users")
@APIResponse(responseCode = "401", description = "Not authenticated")
@APIResponse(
        responseCode = "403",
        description = "Not allowed to do this",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
@APIResponse(
        responseCode = "404",
        description = "Not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
public class MeResource {

    private final CurrentUserService currentUserService;
    private final AccountDeletionService accountDeletionService;

    @Inject
    public MeResource(
            CurrentUserService currentUserService, AccountDeletionService accountDeletionService) {
        this.currentUserService = currentUserService;
        this.accountDeletionService = accountDeletionService;
    }

    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = UserResponse.class)))
    @Operation(
            operationId = "syncMyProfile",
            summary = "Create or update the caller profile from the identity token claims")
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
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

    @Operation(operationId = "getMyProfile", summary = "Get the caller profile")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = UserResponse.class)))
    @GET
    public UserResponse me() {
        return UserResponse.from(currentUserService.requireCurrentUser());
    }

    @Operation(
            operationId = "deleteMyAccount",
            summary =
                    "Delete the caller's account: leave every household, anonymize the profile and"
                            + " have the other services and the identity provider remove the rest")
    @APIResponse(
            responseCode = "202",
            description =
                    "Accepted: the profile and memberships are already gone; telling the other"
                            + " services and the identity provider continues until each confirmed")
    @APIResponse(
            responseCode = "409",
            description = "The caller is the only admin of a household that has other members",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @DELETE
    public Response deleteMyAccount() {
        accountDeletionService.deleteMyAccount();
        return Response.accepted().build();
    }
}
