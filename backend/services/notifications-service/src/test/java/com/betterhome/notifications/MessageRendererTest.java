package com.betterhome.notifications;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.notifications.domain.NotificationType;
import com.betterhome.notifications.service.MessageRenderer;
import com.betterhome.notifications.service.MessageRenderer.Message;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class MessageRendererTest {

    private final MessageRenderer renderer = new MessageRenderer();

    private static Map<String, String> payloadFor(NotificationType type) {
        Map<String, String> payload = new HashMap<>();
        for (String key : type.requiredPayloadKeys()) {
            payload.put(key, "Vacuum");
        }
        return payload;
    }

    @Test
    void everyTypeHasAnEnglishAndAFrenchTextWithNoPlaceholderLeft() {
        for (NotificationType type : NotificationType.values()) {
            for (String language : new String[] {"en", "fr"}) {
                Message message = renderer.render(type, payloadFor(type), language);

                assertFalse(message.title().isBlank(), type + "/" + language + " title");
                assertFalse(message.body().isBlank(), type + "/" + language + " body");
                assertFalse(message.title().contains("{"), type + "/" + language + " title");
                assertFalse(message.body().contains("{"), type + "/" + language + " body");
            }
        }
    }

    @Test
    void frenchAndEnglishTextsDiffer() {
        for (NotificationType type : NotificationType.values()) {
            assertNotEquals(
                    renderer.render(type, payloadFor(type), "en"),
                    renderer.render(type, payloadFor(type), "fr"),
                    type.name());
        }
    }

    @Test
    void textsCarryOnlyTheValuesTheEventSent() {
        Message en =
                renderer.render(
                        NotificationType.task_assigned, Map.of("taskTitle", "Dishes"), "en");
        Message fr =
                renderer.render(
                        NotificationType.task_assigned, Map.of("taskTitle", "Vaisselle"), "fr");

        assertEquals("New chore", en.title());
        assertEquals("\"Dishes\" is yours.", en.body());
        assertEquals("Nouvelle tâche", fr.title());
        assertEquals("« Vaisselle » est pour vous.", fr.body());
    }

    @Test
    void unknownOrMissingLanguagesFallBackToEnglishEvenWhenTheJvmDefaultIsFrench() {
        Locale previous = Locale.getDefault();
        Locale.setDefault(Locale.FRENCH);
        try {
            Map<String, String> payload = Map.of("householdName", "Home");
            Message english = renderer.render(NotificationType.invitation, payload, "en");

            assertEquals(english, renderer.render(NotificationType.invitation, payload, "de"));
            assertEquals(english, renderer.render(NotificationType.invitation, payload, null));
            assertEquals(english, renderer.render(NotificationType.invitation, payload, ""));
        } finally {
            Locale.setDefault(previous);
        }
    }

    @Test
    void valuesWithBracesAndDollarSignsAreInsertedVerbatim() {
        Message message =
                renderer.render(
                        NotificationType.task_assigned,
                        Map.of("taskTitle", "{taskTitle} $1 \\"),
                        "en");

        assertTrue(message.body().contains("\"{taskTitle} $1 \\\""));
    }

    @Test
    void languageHintsAreLimitedToSupportedLanguages() {
        assertEquals(Optional.of("fr"), MessageRenderer.parseLanguage("fr"));
        assertEquals(Optional.of("en"), MessageRenderer.parseLanguage("en"));
        assertEquals(Optional.empty(), MessageRenderer.parseLanguage("de"));
        assertEquals(Optional.empty(), MessageRenderer.parseLanguage(null));
        assertEquals("en", MessageRenderer.supportedLanguage("de"));
        assertEquals("fr", MessageRenderer.supportedLanguage("fr"));
    }
}
