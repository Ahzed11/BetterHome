package com.betterhome.households.api;

import com.betterhome.households.domain.HouseholdException;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.ext.ExceptionMapper;
import jakarta.ws.rs.ext.Provider;

@Provider
public class HouseholdExceptionMapper implements ExceptionMapper<HouseholdException> {

    @Override
    public Response toResponse(HouseholdException exception) {
        int status =
                switch (exception) {
                    case HouseholdException.Unauthorized ignored -> 401;
                    case HouseholdException.Forbidden ignored -> 403;
                    case HouseholdException.NotFound ignored -> 404;
                    case HouseholdException.Conflict ignored -> 409;
                    case HouseholdException.BadRequest ignored -> 400;
                    default -> 500;
                };
        return Response.status(status)
                .entity(new ErrorResponse(exception.code(), exception.getMessage()))
                .build();
    }
}
