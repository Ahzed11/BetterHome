package com.betterhome.scoring.api;

import com.betterhome.scoring.domain.PointReason;
import com.betterhome.scoring.domain.PointTransaction;
import com.betterhome.scoring.domain.ReversionResultingStatus;
import com.betterhome.scoring.domain.ScorePeriod;
import com.betterhome.scoring.domain.TaskReversion;
import com.betterhome.scoring.service.AnonymizationService;
import com.betterhome.scoring.service.ScoreboardService;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

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

    /** Rows changed per kind by an account deletion; all zero when nothing was left. */
    public record ScoringAnonymizationResponse(
            @Schema(required = true) int ledgerRows,
            @Schema(required = true) int reversions,
            @Schema(required = true) int recapsWon,
            @Schema(required = true) long celebrationsForgotten) {

        public static ScoringAnonymizationResponse from(AnonymizationService.Result result) {
            return new ScoringAnonymizationResponse(
                    result.ledgerRows(),
                    result.reversions(),
                    result.recapsWon(),
                    result.celebrationsForgotten());
        }
    }

    public record TransactionResponse(
            @Schema(required = true) UUID id,
            @Schema(required = true) UUID householdId,
            @Schema(required = true) UUID userId,
            UUID taskId,
            UUID reversionId,
            @Schema(required = true) int points,
            @Schema(required = true) PointReason reason,
            @Schema(required = true) Instant createdAt) {

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
            @Schema(required = true) UUID id,
            @Schema(required = true) UUID householdId,
            @Schema(required = true) UUID taskId,
            @Schema(required = true) UUID adminUserId,
            @Schema(required = true) String reason,
            @Schema(required = true) int pointsReversed,
            @Schema(required = true) ReversionResultingStatus resultingStatus,
            @Schema(required = true) Instant createdAt) {

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

    public record ScoreEntryResponse(
            @Schema(required = true) UUID userId,
            @Schema(required = true) int points,
            @Schema(required = true) double effortShare,
            @Schema(required = true) int rank) {

        public static ScoreEntryResponse from(ScoreboardService.Entry entry) {
            return new ScoreEntryResponse(
                    entry.userId(), entry.points(), entry.effortShare(), entry.rank());
        }
    }

    public record ScoreboardResponse(
            @Schema(required = true) ScorePeriod period,
            String yearMonth,
            Instant from,
            Instant to,
            @Schema(required = true) int totalPoints,
            @Schema(required = true) List<ScoreEntryResponse> entries,
            @Schema(required = true) List<ScoreEntryResponse> podium) {

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
            @Schema(required = true) String yearMonth,
            UUID winnerUserId,
            @Schema(required = true) int winnerPoints,
            @Schema(required = true) int totalPoints,
            @Schema(required = true) boolean celebrated) {

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

    public record CelebrationSeen(@Schema(required = true) boolean seen) {}
}
