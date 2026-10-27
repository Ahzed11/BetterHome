package com.betterhome.lists.api;

import com.betterhome.lists.domain.Checklist;
import com.betterhome.lists.domain.ChecklistItem;
import com.betterhome.lists.service.AnonymizationService;
import jakarta.validation.constraints.NotBlank;
import java.time.Instant;
import java.util.UUID;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

public final class ListDtos {

    private ListDtos() {}

    public record TitleRequest(@NotBlank String title) {}

    public record ListResponse(
            @Schema(required = true) UUID id,
            @Schema(required = true) UUID householdId,
            @Schema(required = true) String title,
            @Schema(required = true) UUID createdBy,
            @Schema(required = true) Instant createdAt,
            Instant archivedAt) {

        public static ListResponse from(Checklist list) {
            return new ListResponse(
                    list.id,
                    list.householdId,
                    list.title,
                    list.createdBy,
                    list.createdAt,
                    list.archivedAt);
        }
    }

    public record ItemResponse(
            @Schema(required = true) UUID id,
            @Schema(required = true) UUID listId,
            @Schema(required = true) String title,
            @Schema(required = true) int position,
            @Schema(required = true) UUID creator,
            UUID completer,
            Instant completedAt) {

        public static ItemResponse from(ChecklistItem item) {
            return new ItemResponse(
                    item.id,
                    item.listId,
                    item.title,
                    item.position,
                    item.creator,
                    item.completer,
                    item.completedAt);
        }
    }

    /** Rows changed per column by an account deletion; all zero when nothing was left. */
    public record AnonymizationResponse(
            @Schema(required = true) int listsCreated,
            @Schema(required = true) int itemsCreated,
            @Schema(required = true) int itemsCompleted,
            @Schema(required = true) int itemsDeleted) {

        public static AnonymizationResponse from(AnonymizationService.Result result) {
            return new AnonymizationResponse(
                    result.listsCreated(),
                    result.itemsCreated(),
                    result.itemsCompleted(),
                    result.itemsDeleted());
        }
    }
}
