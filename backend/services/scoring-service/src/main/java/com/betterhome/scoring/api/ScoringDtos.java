package com.betterhome.scoring.api;

import com.betterhome.scoring.domain.PointReason;
import com.betterhome.scoring.domain.PointTransaction;
import com.betterhome.scoring.domain.ReversionResultingStatus;
import com.betterhome.scoring.domain.ScorePeriod;
import com.betterhome.scoring.domain.TaskReversion;
import com.betterhome.scoring.service.ScoreboardService;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class ScoringDtos {

    private ScoringDtos() {}

    public record AwardRequest(
            @NotNull UUID userId,
            @NotNull UUID taskId,
            @Positive int completionNo,
            @Positive int points,
            @NotNull PointReason reason) {}

    public record ReverseRequest(
            @NotNull UUID taskId,
            @NotNull UUID assigneeUserId,
            @NotNull UUID adminUserId,
            @Positive int points,
            @NotBlank String reason,
            @NotNull ReversionResultingStatus resultingStatus) {}

    public record AdjustRequest(@NotNull UUID userId, int delta) {}

    public record TransactionResponse(
            UUID id,
            UUID householdId,
            UUID userId,
            UUID taskId,
            UUID reversionId,
            int points,
            PointReason reason,
            Instant createdAt) {

        public static TransactionResponse from(PointTransaction tx) {
            return new TransactionResponse(
                    tx.id,
                    tx.householdId,
                    tx.userId,
                    tx.taskId,
                    tx.reversionId,
                    tx.points,
                    tx.reason,
                    tx.createdAt);
        }
    }

    public record ReversionResponse(
            UUID id,
            UUID householdId,
            UUID taskId,
            UUID adminUserId,
            String reason,
            int pointsReversed,
            ReversionResultingStatus resultingStatus,
            Instant createdAt) {

        public static ReversionResponse from(TaskReversion reversion) {
            return new ReversionResponse(
                    reversion.id,
                    reversion.householdId,
                    reversion.taskId,
                    reversion.adminUserId,
                    reversion.reason,
                    reversion.pointsReversed,
                    reversion.resultingStatus,
                    reversion.createdAt);
        }
    }

    public record ScoreEntryResponse(UUID userId, int points, double effortShare, int rank) {

        public static ScoreEntryResponse from(ScoreboardService.Entry entry) {
            return new ScoreEntryResponse(
                    entry.userId(), entry.points(), entry.effortShare(), entry.rank());
        }
    }

    public record ScoreboardResponse(
            ScorePeriod period,
            String yearMonth,
            Instant from,
            Instant to,
            int totalPoints,
            List<ScoreEntryResponse> entries,
            List<ScoreEntryResponse> podium) {

        public static ScoreboardResponse from(ScoreboardService.Scoreboard board) {
            return new ScoreboardResponse(
                    board.period(),
                    board.yearMonth(),
                    board.from(),
                    board.to(),
                    board.totalPoints(),
                    board.entries().stream().map(ScoreEntryResponse::from).toList(),
                    board.podium().stream().map(ScoreEntryResponse::from).toList());
        }
    }

    /** {@code celebrated}: whether the caller has already seen the confetti of this month. */
    public record WinnerResponse(
            String yearMonth,
            UUID winnerUserId,
            int winnerPoints,
            int totalPoints,
            boolean celebrated) {

        public static WinnerResponse from(ScoreboardService.Winner winner) {
            return new WinnerResponse(
                    winner.yearMonth(),
                    winner.winnerUserId(),
                    winner.winnerPoints(),
                    winner.totalPoints(),
                    winner.celebrated());
        }
    }

    public record CloseMonthRequest(@NotBlank String yearMonth) {}

    public record CelebrationSeen(boolean seen) {}
}
