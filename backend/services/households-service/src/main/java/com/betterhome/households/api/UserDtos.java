package com.betterhome.households.api;

import com.betterhome.households.domain.AppUser;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import java.util.UUID;

public final class UserDtos {

    private UserDtos() {}

    public record SyncUserRequest(
            @NotBlank @Email String email,
            String givenName,
            String familyName,
            String language,
            String timezone) {}

    public record UserResponse(
            UUID id,
            UUID authSubject,
            String email,
            String givenName,
            String familyName,
            String language,
            String timezone) {

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
