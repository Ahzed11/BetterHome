package com.betterhome.notifications.api;

import com.betterhome.notifications.domain.NotificationException;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.ext.ExceptionMapper;
import jakarta.ws.rs.ext.Provider;

@Provider
public class NotificationExceptionMapper implements ExceptionMapper<NotificationException> {

    @Override
    public Response toResponse(NotificationException exception) {
        int status =
                switch (exception) {
                    case NotificationException.Unauthorized ignored -> 401;
                    case NotificationException.Forbidden ignored -> 403;
                    case NotificationException.NotFound ignored -> 404;
                    case NotificationException.BadRequest ignored -> 400;
                    case NotificationException.ServiceUnavailable ignored -> 503;
                    default -> 500;
                };
        return Response.status(status)
                .entity(new ErrorResponse(exception.code(), exception.getMessage()))
                .build();
    }
}
