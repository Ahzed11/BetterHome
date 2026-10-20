package com.betterhome.common.observability;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import jakarta.ws.rs.client.ClientRequestContext;
import jakarta.ws.rs.container.ContainerRequestContext;
import jakarta.ws.rs.container.ContainerResponseContext;
import jakarta.ws.rs.core.MultivaluedHashMap;
import jakarta.ws.rs.core.MultivaluedMap;
import java.lang.reflect.Proxy;
import java.util.UUID;
import org.jboss.logging.MDC;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;

class RequestIdFiltersTest {

    private final RequestIdServerFilter server = new RequestIdServerFilter();
    private final RequestIdClientFilter client = new RequestIdClientFilter();

    @AfterEach
    void clean() {
        MDC.remove(RequestId.MDC_KEY);
    }

    @Test
    void aWellFormedIdFromTheCallerIsKept() {
        assertEquals("abc-DEF_12345", RequestId.acceptOrGenerate("abc-DEF_12345"));
    }

    @Test
    void missingTooShortTooLongOrUnsafeIdsAreReplacedByAUuid() {
        for (String bad :
                new String[] {
                    null,
                    "",
                    "short",
                    "x".repeat(65),
                    "has space 123",
                    "line\nbreak123",
                    "a=b;c=d12"
                }) {
            String id = RequestId.acceptOrGenerate(bad);
            assertNotEquals(bad, id);
            assertEquals(id, UUID.fromString(id).toString());
        }
    }

    @Test
    void theServerFilterPutsTheIdInTheMdcAndEchoesItThenClearsIt() {
        server.filter(request("caller-id-0001"));
        assertEquals("caller-id-0001", MDC.get(RequestId.MDC_KEY));

        MultivaluedMap<String, Object> headers = new MultivaluedHashMap<>();
        server.filter(request("caller-id-0001"), response(headers));

        assertEquals("caller-id-0001", headers.getFirst(RequestId.HEADER));
        assertNull(MDC.get(RequestId.MDC_KEY));
    }

    @Test
    void theServerFilterGeneratesAnIdWhenTheCallerSentNone() {
        server.filter(request(null));
        assertEquals(36, MDC.get(RequestId.MDC_KEY).toString().length());
    }

    @Test
    void theResponseFilterAddsNoHeaderWithoutAnId() {
        MultivaluedMap<String, Object> headers = new MultivaluedHashMap<>();
        server.filter(request(null), response(headers));
        assertTrue(headers.isEmpty());
    }

    @Test
    void theClientFilterForwardsTheCurrentIdOnly() {
        MultivaluedMap<String, Object> headers = new MultivaluedHashMap<>();
        client.filter(outgoing(headers));
        assertTrue(headers.isEmpty(), "no id, nothing to forward");

        MDC.put(RequestId.MDC_KEY, "caller-id-0002");
        client.filter(outgoing(headers));
        assertEquals("caller-id-0002", headers.getFirst(RequestId.HEADER));
    }

    @Test
    void theClientFilterDoesNotOverrideAnExplicitHeader() {
        MDC.put(RequestId.MDC_KEY, "caller-id-0003");
        MultivaluedMap<String, Object> headers = new MultivaluedHashMap<>();
        headers.putSingle(RequestId.HEADER, "explicit-id-9999");

        client.filter(outgoing(headers));

        assertEquals("explicit-id-9999", headers.getFirst(RequestId.HEADER));
    }

    private static ContainerRequestContext request(String requestIdHeader) {
        return (ContainerRequestContext)
                Proxy.newProxyInstance(
                        RequestIdFiltersTest.class.getClassLoader(),
                        new Class<?>[] {ContainerRequestContext.class},
                        (proxy, method, args) ->
                                "getHeaderString".equals(method.getName())
                                        ? requestIdHeader
                                        : null);
    }

    private static ContainerResponseContext response(MultivaluedMap<String, Object> headers) {
        return (ContainerResponseContext)
                Proxy.newProxyInstance(
                        RequestIdFiltersTest.class.getClassLoader(),
                        new Class<?>[] {ContainerResponseContext.class},
                        (proxy, method, args) ->
                                "getHeaders".equals(method.getName()) ? headers : null);
    }

    private static ClientRequestContext outgoing(MultivaluedMap<String, Object> headers) {
        return (ClientRequestContext)
                Proxy.newProxyInstance(
                        RequestIdFiltersTest.class.getClassLoader(),
                        new Class<?>[] {ClientRequestContext.class},
                        (proxy, method, args) ->
                                "getHeaders".equals(method.getName()) ? headers : null);
    }
}
