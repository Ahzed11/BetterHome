import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A small uppercase heading above a group, for example "IN THE BASKET · 2".
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceXs),
      child: Semantics(
        container: true,
        header: true,
        child: Text(text.toUpperCase(), style: AppTypography.sectionLabel),
      ),
    );
  }
}
