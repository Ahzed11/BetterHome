package com.betterhome.lists.api;

import com.betterhome.lists.domain.Checklist;
import com.betterhome.lists.domain.ChecklistItem;
import jakarta.validation.constraints.NotBlank;
import java.time.Instant;
import java.util.UUID;

public final class ListDtos {

    private ListDtos() {}

    public record TitleRequest(@NotBlank String title) {}

    public record ListResponse(
            UUID id,
            UUID householdId,
            String title,
            UUID createdBy,
            Instant createdAt,
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
            UUID id,
            UUID listId,
            String title,
            int position,
            UUID creator,
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
}
