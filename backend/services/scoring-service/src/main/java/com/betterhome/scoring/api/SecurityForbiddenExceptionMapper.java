package com.betterhome.scoring.api;

import io.quarkus.security.ForbiddenException;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.ext.ExceptionMapper;
import jakarta.ws.rs.ext.Provider;

/**
 * Role checks ({@code @RolesAllowed}) answer 403 through Quarkus with an empty body, while domain
 * checks answer 403 with an {@link ErrorResponse}. One status must have one shape, so role denials
 * get the same body.
 */
@Provider
public class SecurityForbiddenExceptionMapper implements ExceptionMapper<ForbiddenException> {

    @Override
    public Response toResponse(ForbiddenException exception) {
        return Response.status(Response.Status.FORBIDDEN)
                .entity(new ErrorResponse("forbidden", "Not allowed to do this"))
                .build();
    }
}
