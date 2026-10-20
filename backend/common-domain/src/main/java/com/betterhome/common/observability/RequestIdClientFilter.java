package com.betterhome.common.observability;

import jakarta.ws.rs.client.ClientRequestContext;
import jakarta.ws.rs.client.ClientRequestFilter;
import jakarta.ws.rs.ext.Provider;
import org.jboss.logging.MDC;

/**
 * Forwards the current request id on outgoing REST client calls, so one user action can be followed
 * across services. Trace context ({@code traceparent}) is propagated by OpenTelemetry itself.
 */
@Provider
public class RequestIdClientFilter implements ClientRequestFilter {

    @Override
    public void filter(ClientRequestContext request) {
        Object id = MDC.get(RequestId.MDC_KEY);
        if (id != null && !request.getHeaders().containsKey(RequestId.HEADER)) {
            request.getHeaders().putSingle(RequestId.HEADER, id.toString());
        }
    }
}
