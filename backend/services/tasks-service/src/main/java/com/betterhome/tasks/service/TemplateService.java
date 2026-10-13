package com.betterhome.tasks.service;

import com.betterhome.common.Clock;
import com.betterhome.tasks.domain.Rotation;
import com.betterhome.tasks.domain.TaskException;
import com.betterhome.tasks.domain.TaskTemplate;
import com.betterhome.tasks.membership.MembershipGateway.MemberView;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@ApplicationScoped
public class TemplateService {

    private final CallerService callerService;
    private final RecurrenceService recurrenceService;
    private final Clock clock;

    @Inject
    public TemplateService(
            CallerService callerService, RecurrenceService recurrenceService, Clock clock) {
        this.callerService = callerService;
        this.recurrenceService = recurrenceService;
        this.clock = clock;
    }

    public List<TaskTemplate> list(UUID householdId) {
        callerService.requireMember(householdId);
        return TaskTemplate.listActive(householdId);
    }

    @Transactional
    public TaskTemplate create(
            UUID householdId,
            String title,
            String emoji,
            String description,
            int points,
            int latePoints,
            Integer defaultDueOffsetMinutes) {
        MemberView admin = callerService.requireAdmin(householdId);
        validateTemplateFields(title, points, latePoints, defaultDueOffsetMinutes);
        Instant now = clock.now();

        Rotation rotation = new Rotation();
        rotation.id = UUID.randomUUID();
        rotation.householdId = householdId;
        rotation.name = title.trim();
        rotation.createdAt = now;
        rotation.persist();

        TaskTemplate template = new TaskTemplate();
        template.id = UUID.randomUUID();
        template.householdId = householdId;
        template.title = title.trim();
        template.emoji = blankToNull(emoji);
        template.description = description == null ? "" : description.trim();
        template.points = points;
        template.latePoints = latePoints;
        template.defaultDueOffsetMinutes =
                defaultDueOffsetMinutes == null ? 1440 : defaultDueOffsetMinutes;
        template.rotationId = rotation.id;
        template.createdBy = admin.userId();
        template.createdAt = now;
        template.updatedAt = now;
        template.persist();
        return template;
    }

    @Transactional
    public TaskTemplate update(
            UUID householdId,
            UUID templateId,
            String title,
            String emoji,
            String description,
            Integer points,
            Integer latePoints,
            Integer defaultDueOffsetMinutes) {
        callerService.requireAdmin(householdId);
        TaskTemplate template =
                TaskTemplate.findActive(householdId, templateId)
                        .orElseThrow(() -> new TaskException.NotFound("Template not found"));
        if (title != null) {
            if (title.isBlank()) {
                throw new TaskException.BadRequest("title must not be blank");
            }
            template.title = title.trim();
        }
        if (emoji != null) {
            template.emoji = blankToNull(emoji);
        }
        if (description != null) {
            template.description = description.trim();
        }
        if (points != null) {
            if (points < 0) {
                throw new TaskException.BadRequest("points must be >= 0");
            }
            template.points = points;
        }
        if (latePoints != null) {
            if (latePoints < 0) {
                throw new TaskException.BadRequest("latePoints must be >= 0");
            }
            template.latePoints = latePoints;
        }
        if (defaultDueOffsetMinutes != null) {
            if (defaultDueOffsetMinutes < 0) {
                throw new TaskException.BadRequest("defaultDueOffsetMinutes must be >= 0");
            }
            template.defaultDueOffsetMinutes = defaultDueOffsetMinutes;
        }
        template.updatedAt = clock.now();
        return template;
    }

    @Transactional
    public TaskTemplate archive(UUID householdId, UUID templateId) {
        callerService.requireAdmin(householdId);
        TaskTemplate template =
                TaskTemplate.findActive(householdId, templateId)
                        .orElseThrow(() -> new TaskException.NotFound("Template not found"));
        Instant now = clock.now();
        template.archivedAt = now;
        template.updatedAt = now;
        recurrenceService.stopForTemplate(householdId, templateId);
        return template;
    }

    private static void validateTemplateFields(
            String title, int points, int latePoints, Integer defaultDueOffsetMinutes) {
        if (title == null || title.isBlank()) {
            throw new TaskException.BadRequest("title is required");
        }
        if (points < 0 || latePoints < 0) {
            throw new TaskException.BadRequest("points and latePoints must be >= 0");
        }
        if (defaultDueOffsetMinutes != null && defaultDueOffsetMinutes < 0) {
            throw new TaskException.BadRequest("defaultDueOffsetMinutes must be >= 0");
        }
    }

    private static String blankToNull(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return value.trim();
    }
}
