package com.betterhome.tasks.service;

import com.betterhome.common.Clock;
import com.betterhome.tasks.domain.AssignmentMode;
import com.betterhome.tasks.domain.RruleEngine;
import com.betterhome.tasks.domain.TaskException;
import com.betterhome.tasks.domain.TaskRecurrence;
import com.betterhome.tasks.domain.TaskTemplate;
import com.betterhome.tasks.membership.MembershipGateway;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.time.ZoneId;
import java.util.Optional;
import java.util.UUID;

@ApplicationScoped
public class RecurrenceService {

    private final CallerService callerService;
    private final MembershipGateway membershipGateway;
    private final Clock clock;

    @Inject
    public RecurrenceService(
            CallerService callerService, MembershipGateway membershipGateway, Clock clock) {
        this.callerService = callerService;
        this.membershipGateway = membershipGateway;
        this.clock = clock;
    }

    public Optional<TaskRecurrence> find(UUID householdId, UUID templateId) {
        callerService.requireMember(householdId);
        return TaskRecurrence.findByTemplate(householdId, templateId);
    }

    @Transactional
    public TaskRecurrence upsert(
            UUID householdId,
            UUID templateId,
            String rrule,
            AssignmentMode mode,
            UUID fixedAssigneeId,
            Instant startsAt,
            Instant endsAt) {
        callerService.requireAdmin(householdId);
        TaskTemplate template =
                TaskTemplate.findActive(householdId, templateId)
                        .orElseThrow(() -> new TaskException.NotFound("Template not found"));
        if (mode == AssignmentMode.fixed) {
            if (fixedAssigneeId == null) {
                throw new TaskException.BadRequest("fixedAssigneeId is required for fixed mode");
            }
            if (!membershipGateway.listActiveMemberIds(householdId).contains(fixedAssigneeId)) {
                throw new TaskException.BadRequest("fixedAssigneeId is not an active member");
            }
        }
        String timezone = membershipGateway.householdSettings(householdId).timezone();
        ZoneId zone;
        try {
            zone = ZoneId.of(timezone);
        } catch (Exception ex) {
            throw new TaskException.BadRequest("Invalid household timezone: " + timezone);
        }
        Instant start = startsAt != null ? startsAt : clock.now();
        if (endsAt != null && !endsAt.isAfter(start)) {
            throw new TaskException.BadRequest("endsAt must be after startsAt");
        }
        // Validate rrule by computing first occurrence
        Instant first =
                RruleEngine.nextOccurrence(rrule, zone, start, endsAt, start.minusSeconds(1))
                        .orElseThrow(
                                () ->
                                        new TaskException.BadRequest(
                                                "RRULE produces no occurrences in range"));

        Instant now = clock.now();
        TaskRecurrence recurrence =
                TaskRecurrence.findByTemplate(householdId, templateId)
                        .orElseGet(
                                () -> {
                                    TaskRecurrence created = new TaskRecurrence();
                                    created.id = UUID.randomUUID();
                                    created.householdId = householdId;
                                    created.templateId = templateId;
                                    created.rotationId = template.rotationId;
                                    created.createdAt = now;
                                    return created;
                                });
        recurrence.rrule = rrule.trim();
        recurrence.assignmentMode = mode;
        recurrence.fixedAssigneeId = mode == AssignmentMode.fixed ? fixedAssigneeId : null;
        recurrence.timezone = timezone;
        recurrence.startsAt = start;
        recurrence.endsAt = endsAt;
        recurrence.nextRunAt = first;
        recurrence.updatedAt = now;
        if (!TaskRecurrence.getEntityManager().contains(recurrence)) {
            recurrence.persist();
        }
        return recurrence;
    }

    @Transactional
    public void stopForTemplate(UUID householdId, UUID templateId) {
        TaskRecurrence.findByTemplate(householdId, templateId)
                .ifPresent(
                        recurrence -> {
                            recurrence.nextRunAt = null;
                            recurrence.updatedAt = clock.now();
                        });
    }
}
