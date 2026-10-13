package com.betterhome.lists.api;

import static org.junit.jupiter.api.Assertions.assertEquals;

import com.betterhome.lists.domain.ListException;
import jakarta.ws.rs.core.Response;
import org.junit.jupiter.api.Test;

class ListExceptionMapperTest {

    private final ListExceptionMapper mapper = new ListExceptionMapper();

    private static final class Unexpected extends ListException {
        Unexpected() {
            super("unexpected", "Something else");
        }
    }

    @Test
    void everyDomainExceptionMapsToItsStatusAndCode() {
        assertMaps(new ListException.Unauthorized("a"), 401, "unauthorized");
        assertMaps(new ListException.Forbidden("a"), 403, "forbidden");
        assertMaps(new ListException.NotFound("a"), 404, "not_found");
        assertMaps(new ListException.Conflict("a"), 409, "conflict");
        assertMaps(new ListException.BadRequest("a"), 400, "bad_request");
        assertMaps(new ListException.ServiceUnavailable("a"), 503, "service_unavailable");
    }

    @Test
    void anUnclassifiedDomainExceptionIsAServerError() {
        assertMaps(new Unexpected(), 500, "unexpected");
    }

    private void assertMaps(ListException exception, int status, String code) {
        try (Response response = mapper.toResponse(exception)) {
            assertEquals(status, response.getStatus());
            assertEquals(new ErrorResponse(code, exception.getMessage()), response.getEntity());
        }
    }
}
