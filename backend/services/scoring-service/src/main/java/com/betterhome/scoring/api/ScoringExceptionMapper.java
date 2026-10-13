package com.betterhome.scoring.api;

import com.betterhome.scoring.domain.ScoringException;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.ext.ExceptionMapper;
import jakarta.ws.rs.ext.Provider;

@Provider
public class ScoringExceptionMapper implements ExceptionMapper<ScoringException> {

    @Override
    public Response toResponse(ScoringException exception) {
        int status =
                switch (exception) {
                    case ScoringException.Unauthorized ignored -> 401;
                    case ScoringException.Forbidden ignored -> 403;
                    case ScoringException.NotFound ignored -> 404;
                    case ScoringException.Conflict ignored -> 409;
                    case ScoringException.BadRequest ignored -> 400;
                    default -> 500;
                };
        return Response.status(status)
                .entity(new ErrorResponse(exception.code(), exception.getMessage()))
                .build();
    }
}
