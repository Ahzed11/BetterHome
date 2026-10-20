import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/widgets/member_avatar.dart';
import 'package:flutter/material.dart';

/// One place of the podium: who, their points and the rank.
class PodiumPlace {
  const PodiumPlace({
    required this.rank,
    required this.label,
    required this.points,
    required this.color,
  });

  final int rank;
  final String label;
  final String points;
  final Color color;
}

/// The three places of the leaderboard in the order 2, 1, 3, the winner tallest and ringed in
/// gold. [places] holds up to three entries by rank; a missing one is drawn as an empty, dashed
/// place named [emptyLabel].
class Podium extends StatelessWidget {
  const Podium({super.key, required this.places, required this.emptyLabel});

  final List<PodiumPlace> places;
  final String emptyLabel;

  PodiumPlace? _at(int rank) => places.where((p) => p.rank == rank).firstOrNull;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final rank in const [2, 1, 3]) ...[
          Expanded(
            child: _Column(
              rank: rank,
              place: _at(rank),
              emptyLabel: emptyLabel,
            ),
          ),
          if (rank != 3) const SizedBox(width: AppTokens.spaceSm),
        ],
      ],
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.rank,
    required this.place,
    required this.emptyLabel,
  });

  final int rank;
  final PodiumPlace? place;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final first = rank == 1;
    final height = first
        ? 116.0
        : rank == 2
        ? 80.0
        : 56.0;
    final place = this.place;
    final rankStyle = AppTypography.display.copyWith(
      fontSize: first ? 34 : 28,
      color: first ? AppTokens.podiumGoldInk : AppTokens.inkMuted,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (place != null) ...[
          MemberAvatar(
            label: place.label,
            color: place.color,
            size: first ? 76 : 60,
            ring: first ? AppTokens.goldRing : AppTokens.controlOutline,
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Semantics(
            container: true,
            label: '${place.rank}. ${place.label}, ${place.points}',
            child: ExcludeSemantics(
              child: Column(
                children: [
                  Text(
                    place.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    place.points,
                    style: AppTypography.label.copyWith(
                      color: AppTokens.brand,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: AppTokens.spaceSm),
          Text(
            emptyLabel,
            textAlign: TextAlign.center,
            style: AppTypography.eyebrow.copyWith(fontSize: 13),
          ),
        ],
        const SizedBox(height: AppTokens.spaceSm),
        Container(
          height: height,
          width: double.infinity,
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            color: place == null
                ? null
                : first
                ? AppTokens.podiumGold
                : AppTokens.podiumSilver,
            border: place == null
                ? Border.all(color: AppTokens.outline, width: 2)
                : null,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(18),
              bottom: Radius.circular(6),
            ),
          ),
          child: ExcludeSemantics(child: Text('$rank', style: rankStyle)),
        ),
      ],
    );
  }
}
