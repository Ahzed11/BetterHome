package com.betterhome.lists.api;

import com.betterhome.lists.domain.ListException;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.ext.ExceptionMapper;
import jakarta.ws.rs.ext.Provider;

@Provider
public class ListExceptionMapper implements ExceptionMapper<ListException> {

    @Override
    public Response toResponse(ListException exception) {
        int status =
                switch (exception) {
                    case ListException.Unauthorized ignored -> 401;
                    case ListException.Forbidden ignored -> 403;
                    case ListException.NotFound ignored -> 404;
                    case ListException.Conflict ignored -> 409;
                    case ListException.BadRequest ignored -> 400;
                    case ListException.ServiceUnavailable ignored -> 503;
                    default -> 500;
                };
        return Response.status(status)
                .entity(new ErrorResponse(exception.code(), exception.getMessage()))
                .build();
    }
}
