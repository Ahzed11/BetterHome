package com.betterhome.households.service;

import java.util.UUID;

/** Fired inside the transaction that marks a member away, observed once it has committed. */
public record MemberAway(UUID householdId, UUID userId) {}
