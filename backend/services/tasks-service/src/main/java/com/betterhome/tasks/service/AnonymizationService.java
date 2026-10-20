package com.betterhome.tasks.service;

import com.betterhome.common.Clock;
import com.betterhome.tasks.domain.NotificationOutbox;
import com.betterhome.tasks.domain.Rotation;
import com.betterhome.tasks.domain.SystemActors;
import com.betterhome.tasks.domain.Task;
import com.betterhome.tasks.domain.TaskException;
import com.betterhome.tasks.domain.TaskRecurrence;
import com.betterhome.tasks.domain.TaskTemplate;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.util.UUID;

/**
 * Account deletion (spec §9): replaces a deleted user's id with {@link #ANONYMOUS} in every column
 * that records who did something, so tasks keep their history without the person. Open tasks the
 * user still held are dismissed first: nobody can do them any more.
 */
@ApplicationScoped
public class AnonymizationService {

    /** The id that replaces every deleted user; it never belongs to a real user. */
    public static final UUID ANONYMOUS = new UUID(0L, 0L);

    /** Rows changed per kind. All zero when the user has no history here, or already left. */
    public record Result(
            int openTasksDismissed,
            int tasksAssigned,
            int tasksCompleted,
            int tasksDismissed,
            int templatesCreated,
            int recurrencesFixed,
            int rotationCursors,
            long queuedNotificationsDropped) {}

    private final Clock clock;

    @Inject
    public AnonymizationService(Clock clock) {
        this.clock = clock;
    }

    /** Idempotent: a second call for the same user finds nothing left to change. */
    @Transactional
    public Result anonymize(UUID userId) {
        if (ANONYMOUS.equals(userId)) {
            throw new TaskException.BadRequest("Not a user id");
        }
        int dismissedOpen = Task.dismissOpenOf(userId, SystemActors.AUTOMATION, clock.now());
        return new Result(
                dismissedOpen,
                Task.replaceAssignee(userId, ANONYMOUS),
                Task.replaceCompleter(userId, ANONYMOUS),
                Task.replaceDismissedBy(userId, ANONYMOUS),
                TaskTemplate.replaceCreator(userId, ANONYMOUS),
                TaskRecurrence.replaceFixedAssignee(userId, ANONYMOUS),
                Rotation.replaceLastAssigned(userId, ANONYMOUS),
                NotificationOutbox.deleteForUser(userId));
    }
}
