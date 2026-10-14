package com.betterhome.lists.domain;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.LockModeType;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/** A household's list. Every list is a checklist; checking an item awards no points. */
@Entity
@Table(name = "list")
public class Checklist extends PanacheEntityBase {

    @Id public UUID id;

    @Column(name = "household_id", nullable = false)
    public UUID householdId;

    @Column(nullable = false)
    public String title;

    @Column(name = "created_by", nullable = false)
    public UUID createdBy;

    @Column(name = "created_at", nullable = false)
    public Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    public Instant updatedAt;

    @Column(name = "archived_at")
    public Instant archivedAt;

    public static Checklist create(UUID householdId, String title, UUID createdBy, Instant now) {
        Checklist list = new Checklist();
        list.id = UUID.randomUUID();
        list.householdId = householdId;
        list.title = Titles.require(title);
        list.createdBy = createdBy;
        list.createdAt = now;
        list.updatedAt = now;
        return list;
    }

    public boolean isArchived() {
        return archivedAt != null;
    }

    /** Items of an archived list are frozen; reading them stays possible. */
    public void requireActive() {
        if (isArchived()) {
            throw new ListException.Conflict("List is archived");
        }
    }

    public void rename(String newTitle, Instant now) {
        requireActive();
        title = Titles.require(newTitle);
        updatedAt = now;
    }

    public void archive(Instant now) {
        requireActive();
        archivedAt = now;
        updatedAt = now;
    }

    public static Optional<Checklist> findInHousehold(UUID householdId, UUID listId) {
        return find("id = ?1 and householdId = ?2", listId, householdId).firstResultOptional();
    }

    /** Same as {@link #findInHousehold} but serializes concurrent writers of the same list. */
    public static Optional<Checklist> lockInHousehold(UUID householdId, UUID listId) {
        return find("id = ?1 and householdId = ?2", listId, householdId)
                .withLock(LockModeType.PESSIMISTIC_WRITE)
                .firstResultOptional();
    }

    public static List<Checklist> listForHousehold(UUID householdId, boolean includeArchived) {
        if (includeArchived) {
            return list("householdId = ?1 order by createdAt, id", householdId);
        }
        return list("householdId = ?1 and archivedAt is null order by createdAt, id", householdId);
    }
}
