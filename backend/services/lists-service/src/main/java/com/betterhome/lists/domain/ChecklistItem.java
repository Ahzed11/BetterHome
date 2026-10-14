package com.betterhome.lists.domain;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/** One line of a checklist. Deleting is soft: the row keeps who deleted it and when. */
@Entity
@Table(name = "item")
public class ChecklistItem extends PanacheEntityBase {

    @Id public UUID id;

    @Column(name = "list_id", nullable = false)
    public UUID listId;

    @Column(nullable = false)
    public String title;

    @Column(nullable = false)
    public int position;

    @Column(nullable = false)
    public UUID creator;

    public UUID completer;

    @Column(name = "completed_at")
    public Instant completedAt;

    @Column(name = "deleted_by")
    public UUID deletedBy;

    @Column(name = "deleted_at")
    public Instant deletedAt;

    @Column(name = "created_at", nullable = false)
    public Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    public Instant updatedAt;

    public static ChecklistItem create(
            UUID listId, String title, int position, UUID creator, Instant now) {
        ChecklistItem item = new ChecklistItem();
        item.id = UUID.randomUUID();
        item.listId = listId;
        item.title = Titles.require(title);
        item.position = position;
        item.creator = creator;
        item.createdAt = now;
        item.updatedAt = now;
        return item;
    }

    public boolean isChecked() {
        return completedAt != null;
    }

    public void rename(String newTitle, Instant now) {
        title = Titles.require(newTitle);
        updatedAt = now;
    }

    /** Checking an already checked item keeps the first completer and time. */
    public void check(UUID by, Instant now) {
        if (isChecked()) {
            return;
        }
        completer = by;
        completedAt = now;
        updatedAt = now;
    }

    public void uncheck(Instant now) {
        if (!isChecked()) {
            return;
        }
        completer = null;
        completedAt = null;
        updatedAt = now;
    }

    public void softDelete(UUID by, Instant now) {
        deletedBy = by;
        deletedAt = now;
        updatedAt = now;
    }

    /** A live (not deleted) item of the given list. */
    public static Optional<ChecklistItem> findLive(UUID listId, UUID itemId) {
        return find("id = ?1 and listId = ?2 and deletedAt is null", itemId, listId)
                .firstResultOptional();
    }

    public static List<ChecklistItem> listLive(UUID listId) {
        return list("listId = ?1 and deletedAt is null order by position", listId);
    }

    /**
     * One past the highest position ever used, deleted items included, so positions never clash.
     */
    public static int nextPosition(UUID listId) {
        Integer highest =
                getEntityManager()
                        .createQuery(
                                "select max(i.position) from ChecklistItem i where i.listId = ?1",
                                Integer.class)
                        .setParameter(1, listId)
                        .getSingleResult();
        return highest == null ? 0 : highest + 1;
    }

    /** Unchecks every live item of the list; returns how many were checked. */
    public static int uncheckAll(UUID listId, Instant now) {
        return update(
                "completer = null, completedAt = null, updatedAt = ?2 "
                        + "where listId = ?1 and deletedAt is null and completedAt is not null",
                listId,
                now);
    }
}
