package com.betterhome.tasks.api;

import com.betterhome.tasks.domain.AssignmentMode;
import com.betterhome.tasks.domain.DismissalReason;
import com.betterhome.tasks.domain.Task;
import com.betterhome.tasks.domain.TaskOrigin;
import com.betterhome.tasks.domain.TaskRecurrence;
import com.betterhome.tasks.domain.TaskStatus;
import com.betterhome.tasks.domain.TaskTemplate;
import com.betterhome.tasks.service.AnonymizationService;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import java.util.UUID;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

public final class TaskDtos {

    private TaskDtos() {}

    public record CreateTemplateRequest(
            @NotBlank String title,
            String emoji,
            String description,
            @Min(0) int points,
            @Min(0) int latePoints,
            @Min(0) Integer defaultDueOffsetMinutes) {}

    public record UpdateTemplateRequest(
            String title,
            String emoji,
            String description,
            @Min(0) Integer points,
            @Min(0) Integer latePoints,
            @Min(0) Integer defaultDueOffsetMinutes) {}

    public record TemplateResponse(
            @Schema(required = true) UUID id,
            @Schema(required = true) UUID householdId,
            @Schema(required = true) String title,
            String emoji,
            @Schema(required = true) String description,
            @Schema(required = true) int points,
            @Schema(required = true) int latePoints,
            @Schema(required = true) int defaultDueOffsetMinutes,
            @Schema(required = true) UUID rotationId,
            Instant archivedAt) {

        public static TemplateResponse from(TaskTemplate template) {
            return new TemplateResponse(
                    template.id,
                    template.householdId,
                    template.title,
                    template.emoji,
                    template.description,
                    template.points,
                    template.latePoints,
                    template.defaultDueOffsetMinutes,
                    template.rotationId,
                    template.archivedAt);
        }
    }

    public record CreateOpenTaskRequest(@NotNull UUID templateId, UUID assigneeId, Instant dueAt) {}

    public record QuickLogRequest(@NotNull UUID templateId) {}

    public record DismissedCount(@Schema(required = true) int dismissed) {}

    /** Rows changed per kind by an account deletion; all zero when nothing was left. */
    public record TasksAnonymizationResponse(
            @Schema(required = true) int openTasksDismissed,
            @Schema(required = true) int tasksAssigned,
            @Schema(required = true) int tasksCompleted,
            @Schema(required = true) int tasksDismissed,
            @Schema(required = true) int templatesCreated,
            @Schema(required = true) int recurrencesFixed,
            @Schema(required = true) int rotationCursors,
            @Schema(required = true) long queuedNotificationsDropped) {

        public static TasksAnonymizationResponse from(AnonymizationService.Result result) {
            return new TasksAnonymizationResponse(
                    result.openTasksDismissed(),
                    result.tasksAssigned(),
                    result.tasksCompleted(),
                    result.tasksDismissed(),
                    result.templatesCreated(),
                    result.recurrencesFixed(),
                    result.rotationCursors(),
                    result.queuedNotificationsDropped());
        }
    }

    public record ReassignedCount(@Schema(required = true) int reassigned) {}

    public record RevertRequest(@NotBlank String reason) {}

    public record UpsertRecurrenceRequest(
            @NotBlank String rrule,
            @NotNull AssignmentMode assignmentMode,
            UUID fixedAssigneeId,
            Instant startsAt,
            Instant endsAt) {}

    public record RecurrenceResponse(
            @Schema(required = true) UUID id,
            @Schema(required = true) UUID householdId,
            @Schema(required = true) UUID templateId,
            @Schema(required = true) String rrule,
            @Schema(required = true) AssignmentMode assignmentMode,
            UUID fixedAssigneeId,
            @Schema(required = true) String timezone,
            @Schema(required = true) Instant startsAt,
            Instant endsAt,
            Instant lastGeneratedAt,
            Instant nextRunAt) {

        public static RecurrenceResponse from(TaskRecurrence recurrence) {
            return new RecurrenceResponse(
                    recurrence.id,
                    recurrence.householdId,
                    recurrence.templateId,
                    recurrence.rrule,
                    recurrence.assignmentMode,
                    recurrence.fixedAssigneeId,
                    recurrence.timezone,
                    recurrence.startsAt,
                    recurrence.endsAt,
                    recurrence.lastGeneratedAt,
                    recurrence.nextRunAt);
        }
    }

    public record TaskResponse(
            @Schema(required = true) UUID id,
            @Schema(required = true) UUID householdId,
            @Schema(required = true) UUID templateId,
            @Schema(required = true) TaskOrigin origin,
            @Schema(required = true) String title,
            String emoji,
            @Schema(required = true) String description,
            @Schema(required = true) int points,
            @Schema(required = true) int latePoints,
            @Schema(required = true) TaskStatus status,
            @Schema(required = true) UUID assigneeId,
            UUID completerId,
            UUID dismissedBy,
            DismissalReason dismissalReason,
            Instant dueAt,
            Instant completedAt,
            Integer pointsAwarded,
            String reversionReason) {

        public static TaskResponse from(Task task) {
            return new TaskResponse(
                    task.id,
                    task.householdId,
                    task.templateId,
                    task.origin,
                    task.title,
                    task.emoji,
                    task.description,
                    task.points,
                    task.latePoints,
                    task.status,
                    task.assigneeId,
                    task.completerId,
                    task.dismissedBy,
                    task.dismissalReason,
                    task.dueAt,
                    task.completedAt,
                    task.pointsAwarded,
                    task.reversionReason);
        }
    }
}
