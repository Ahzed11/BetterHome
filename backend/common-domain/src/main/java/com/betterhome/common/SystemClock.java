package com.betterhome.common;

import jakarta.enterprise.context.ApplicationScoped;
import java.time.Instant;

@ApplicationScoped
public class SystemClock implements Clock {

    @Override
    public Instant now() {
        return Instant.now();
    }
}
