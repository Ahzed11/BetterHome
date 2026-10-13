package com.betterhome.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;

import com.betterhome.common.PushSender.PushMessage;
import org.junit.jupiter.api.Test;

class PushMessageTest {

    @Test
    void exposesItsComponentsAndComparesByValue() {
        PushMessage message = new PushMessage("u", "type", "title", "body", "{}");

        assertEquals("u", message.userId());
        assertEquals("type", message.type());
        assertEquals("title", message.title());
        assertEquals("body", message.body());
        assertEquals("{}", message.payloadJson());
        assertEquals(message, new PushMessage("u", "type", "title", "body", "{}"));
        assertNotEquals(message, new PushMessage("v", "type", "title", "body", "{}"));
    }
}
