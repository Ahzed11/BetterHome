package com.betterhome.scoring.domain;

/**
 * The rules that keep the points ledger sound (spec §3.4, AGENTS §7): reversals take back only what
 * was awarded, adjustments never push a score below zero, and a score is never shown below zero.
 * Pure, so they can be checked against every input.
 */
public final class LedgerRules {

    private LedgerRules() {}

    /**
     * Whether {@code pointsToReverse} may be taken back from a task whose ledger rows currently sum
     * to {@code netForTask}: a positive number, and no more than what remains on the task.
     */
    public static boolean canReverse(int netForTask, int pointsToReverse) {
        return pointsToReverse > 0 && netForTask >= pointsToReverse;
    }

    /** Whether adding {@code delta} to a member's current ledger sum keeps it at zero or more. */
    public static boolean adjustmentKeepsScoreNonNegative(int currentSum, int delta) {
        return (long) currentSum + delta >= 0;
    }

    /** The score shown for a ledger sum: never below zero. */
    public static int score(int ledgerSum) {
        return Math.max(0, ledgerSum);
    }
}
