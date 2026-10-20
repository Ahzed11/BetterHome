package com.betterhome.common.observability;

import java.util.UUID;
import java.util.regex.Pattern;

/** The request id: its header, its MDC key and the rule for accepting one sent by a caller. */
public final class RequestId {

    /** Header read from the caller, echoed in the answer and sent on outgoing REST calls. */
    public static final String HEADER = "X-Request-ID";

    /** MDC key; the JSON log layout prints every MDC entry. */
    public static final String MDC_KEY = "requestId";

    /** Only short, plain tokens are accepted, so a caller cannot inject log lines or secrets. */
    private static final Pattern ACCEPTED = Pattern.compile("[A-Za-z0-9_-]{8,64}");

    private RequestId() {}

    /** The caller's id when it is well formed, otherwise a new random one. */
    public static String acceptOrGenerate(String fromCaller) {
        if (fromCaller != null && ACCEPTED.matcher(fromCaller).matches()) {
            return fromCaller;
        }
        return UUID.randomUUID().toString();
    }
}
