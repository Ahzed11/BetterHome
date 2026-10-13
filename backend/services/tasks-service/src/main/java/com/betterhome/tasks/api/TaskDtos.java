package com.betterhome.tasks.api;

import com.betterhome.tasks.domain.DismissalReason;
import com.betterhome.tasks.domain.Task;
import com.betterhome.tasks.domain.TaskOrigin;
import com.betterhome.tasks.domain.TaskStatus;
import com.betterhome.tasks.domain.TaskTemplate;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import java.util.UUID;

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
            UUID id,
            UUID householdId,
            String title,
            String emoji,
            String description,
            int points,
            int latePoints,
            int defaultDueOffsetMinutes,
            UUID rotationId,
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

    public record CreateOpenTaskRequest(
            @NotNull UUID templateId, UUID assigneeId, Instant dueAt) {}

    public record QuickLogRequest(@NotNull UUID templateId) {}

    public record RevertRequest(@NotBlank String reason) {}

    public record TaskResponse(
            UUID id,
            UUID householdId,
            UUID templateId,
            TaskOrigin origin,
            String title,
            String emoji,
            String description,
            int points,
            int latePoints,
            TaskStatus status,
            UUID assigneeId,
            UUID completerId,
            UUID dismissedBy,
            DismissalReason dismissalReason,
            Instant dueAt,
            Instant completedAt,
            Integer pointsAwarded) {

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
                    task.pointsAwarded);
        }
    }
}
