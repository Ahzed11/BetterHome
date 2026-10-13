package com.betterhome.tasks.api;

import com.betterhome.tasks.domain.TaskException;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.ext.ExceptionMapper;
import jakarta.ws.rs.ext.Provider;

@Provider
public class TaskExceptionMapper implements ExceptionMapper<TaskException> {

    @Override
    public Response toResponse(TaskException exception) {
        int status =
                switch (exception) {
                    case TaskException.Unauthorized ignored -> 401;
                    case TaskException.Forbidden ignored -> 403;
                    case TaskException.NotFound ignored -> 404;
                    case TaskException.Conflict ignored -> 409;
                    case TaskException.BadRequest ignored -> 400;
                    default -> 500;
                };
        return Response.status(status)
                .entity(new ErrorResponse(exception.code(), exception.getMessage()))
                .build();
    }
}
