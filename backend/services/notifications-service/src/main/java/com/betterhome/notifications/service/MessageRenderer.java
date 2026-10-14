package com.betterhome.notifications.service;

import com.betterhome.notifications.domain.NotificationType;
import jakarta.enterprise.context.ApplicationScoped;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.ResourceBundle;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Renders notification text from the resource bundles {@code i18n/notifications_<lang>.properties}.
 * Placeholders look like {@code {taskTitle}} and are filled from the event payload in a single
 * pass, so a value that itself contains braces is never expanded again.
 */
@ApplicationScoped
public class MessageRenderer {

    public static final String DEFAULT_LANGUAGE = "en";

    private static final String BUNDLE = "i18n.notifications";
    private static final Pattern PLACEHOLDER = Pattern.compile("\\{(\\w+)}");
    private static final ResourceBundle.Control EXACT_LANGUAGE =
            ResourceBundle.Control.getNoFallbackControl(ResourceBundle.Control.FORMAT_PROPERTIES);

    /** The title and body shown to the recipient. */
    public record Message(String title, String body) {}

    /** The language to render in: {@code fr} or {@code en}, anything else becomes English. */
    public static String supportedLanguage(String language) {
        return "fr".equals(language) ? "fr" : DEFAULT_LANGUAGE;
    }

    /** A supported language from a hint, if the hint names one. */
    public static Optional<String> parseLanguage(String hint) {
        if ("fr".equals(hint) || "en".equals(hint)) {
            return Optional.of(hint);
        }
        return Optional.empty();
    }

    public Message render(NotificationType type, Map<String, String> payload, String language) {
        ResourceBundle bundle =
                ResourceBundle.getBundle(
                        BUNDLE, Locale.forLanguageTag(supportedLanguage(language)), EXACT_LANGUAGE);
        return new Message(
                fill(bundle.getString(type.name() + ".title"), payload),
                fill(bundle.getString(type.name() + ".body"), payload));
    }

    private static String fill(String template, Map<String, String> payload) {
        Matcher matcher = PLACEHOLDER.matcher(template);
        StringBuilder out = new StringBuilder();
        while (matcher.find()) {
            String value = payload.getOrDefault(matcher.group(1), "");
            matcher.appendReplacement(out, Matcher.quoteReplacement(value));
        }
        matcher.appendTail(out);
        return out.toString();
    }
}
