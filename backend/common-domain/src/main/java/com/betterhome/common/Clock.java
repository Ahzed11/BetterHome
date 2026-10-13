package com.betterhome.common;

import java.time.Instant;

/**
 * Injectable time source. Domain code must not call {@link java.time.Clock#systemUTC()} directly.
 */
public interface Clock {

    Instant now();
}
