package com.betterhome.households.api;

import com.betterhome.households.domain.AppUser;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import java.util.UUID;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

public final class UserDtos {

    private UserDtos() {}

    public record SyncUserRequest(
            @NotBlank @Email String email,
            String givenName,
            String familyName,
            String language,
            String timezone) {}

    public record UserResponse(
            @Schema(required = true) UUID id,
            @Schema(required = true) UUID authSubject,
            @Schema(required = true) String email,
            @Schema(required = true) String givenName,
            @Schema(required = true) String familyName,
            @Schema(required = true) String language,
            @Schema(required = true) String timezone) {

        public static UserResponse from(AppUser user) {
            return new UserResponse(
                    user.id,
                    user.authSubject,
                    user.email,
                    user.givenName,
                    user.familyName,
                    user.language,
                    user.timezone);
        }
    }
}
