package com.betterhome.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.common.PushSender.PushMessage;
import java.util.ArrayList;
import java.util.List;
import java.util.logging.Handler;
import java.util.logging.Level;
import java.util.logging.LogRecord;
import java.util.logging.Logger;
import org.junit.jupiter.api.Test;

class NoOpPushSenderTest {

    private static final PushMessage MESSAGE =
            new PushMessage("user-1", "TASK_ASSIGNED", "Title", "Body", "{\"taskId\":\"t1\"}");

    /** Collects the messages logged by the sender. */
    private static final class CollectingHandler extends Handler {
        private final List<String> messages = new ArrayList<>();

        @Override
        public void publish(LogRecord record) {
            messages.add(record.getMessage());
        }

        @Override
        public void flush() {
            // nothing buffered
        }

        @Override
        public void close() {
            messages.clear();
        }
    }

    private static List<String> sendCollectingLogs(Level level) {
        Logger logger = Logger.getLogger(NoOpPushSender.class.getName());
        Level previous = logger.getLevel();
        CollectingHandler handler = new CollectingHandler();
        handler.setLevel(Level.ALL);
        logger.addHandler(handler);
        logger.setLevel(level);
        try {
            new NoOpPushSender().send(MESSAGE);
            return List.copyOf(handler.messages);
        } finally {
            logger.removeHandler(handler);
            logger.setLevel(previous);
        }
    }

    @Test
    void sendLogsTypeAndUserButNeverTheContent() {
        List<String> logged = sendCollectingLogs(Level.FINE);

        assertEquals(1, logged.size());
        assertTrue(logged.get(0).contains("type=TASK_ASSIGNED"));
        assertTrue(logged.get(0).contains("user=user-1"));
        assertFalse(logged.get(0).contains("Body"));
        assertFalse(logged.get(0).contains("taskId"));
    }

    @Test
    void sendLogsNothingAtDefaultLevel() {
        assertTrue(sendCollectingLogs(Level.INFO).isEmpty());
    }
}
