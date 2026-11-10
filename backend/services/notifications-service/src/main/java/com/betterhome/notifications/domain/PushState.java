package com.betterhome.notifications.domain;

/** How the delivery of a push row went. {@link #pending} is the only state that is tried again. */
public enum PushState {
    pending,
    sent,
    skipped,
    refused,
    gave_up
}
