package com.betterhome.common.testclock;

import com.betterhome.common.SystemClock;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import java.time.Duration;
import org.eclipse.microprofile.config.inject.ConfigProperty;

/**
 * Moves the service's clock for the end-to-end journeys (AGENTS §6.2). It answers 404 unless {@code
 * betterhome.test-clock.enabled} is true, which only the local test stack sets, and it is left out
 * of the OpenAPI document and the app's generated client.
 */
@Path("/v1/test/clock")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class TestClockResource {

    private final boolean enabled;
    private final SystemClock clock;

    @Inject
    public TestClockResource(
            @ConfigProperty(name = "betterhome.test-clock.enabled", defaultValue = "false")
                    boolean enabled,
            SystemClock clock) {
        this.enabled = enabled;
        this.clock = clock;
    }

    @GET
    @RolesAllowed({"member", "admin"})
    public ClockState get() {
        return state();
    }

    /** Sets how far the clock runs ahead of the system time; 0 puts it back. */
    @PUT
    @RolesAllowed({"member", "admin"})
    public ClockState set(SetClock request) {
        requireEnabled();
        clock.shiftBy(Duration.ofSeconds(request.offsetSeconds()));
        return state();
    }

    private ClockState state() {
        requireEnabled();
        return new ClockState(clock.now().toString(), clock.offset().toSeconds());
    }

    private void requireEnabled() {
        if (!enabled) {
            throw new NotFoundException();
        }
    }

    public record SetClock(long offsetSeconds) {}

    public record ClockState(String now, long offsetSeconds) {}
}
