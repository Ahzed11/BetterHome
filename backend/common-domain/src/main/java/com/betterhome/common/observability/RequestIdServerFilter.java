package com.betterhome.common.observability;

import jakarta.ws.rs.container.ContainerRequestContext;
import jakarta.ws.rs.container.ContainerRequestFilter;
import jakarta.ws.rs.container.ContainerResponseContext;
import jakarta.ws.rs.container.ContainerResponseFilter;
import jakarta.ws.rs.ext.Provider;
import org.jboss.logging.MDC;

/**
 * Gives every incoming request an id (the caller's {@code X-Request-ID} when well formed), puts it
 * in the logging MDC so every JSON log line of the request carries it, and echoes it in the answer.
 * Only the id is handled: no other header value is read or logged.
 */
@Provider
public class RequestIdServerFilter implements ContainerRequestFilter, ContainerResponseFilter {

    @Override
    public void filter(ContainerRequestContext request) {
        String id = RequestId.acceptOrGenerate(request.getHeaderString(RequestId.HEADER));
        MDC.put(RequestId.MDC_KEY, id);
    }

    @Override
    public void filter(ContainerRequestContext request, ContainerResponseContext response) {
        Object id = MDC.get(RequestId.MDC_KEY);
        if (id != null) {
            response.getHeaders().putSingle(RequestId.HEADER, id.toString());
        }
        MDC.remove(RequestId.MDC_KEY);
    }
}
