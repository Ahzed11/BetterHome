package com.betterhome.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;

import org.junit.jupiter.api.Test;

class NotificationDeliveryExceptionTest {

    @Test
    void anUnavailableServiceCarriesItsReason() {
        NotificationDeliveryException error = new NotificationDeliveryException.Unavailable("down");

        assertEquals("down", error.getMessage());
        assertInstanceOf(NotificationDeliveryException.Unavailable.class, error);
    }

    @Test
    void aRefusalCarriesItsReasonAndIsADifferentKindFromUnavailable() {
        NotificationDeliveryException error =
                new NotificationDeliveryException.Rejected("bad type");

        assertEquals("bad type", error.getMessage());
        assertInstanceOf(NotificationDeliveryException.Rejected.class, error);
    }
}
