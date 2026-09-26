import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class GameEntry {
  final IconData icon;
  final String name;
  const GameEntry(this.icon, this.name);
}

/// Sheet shown over a voice room when the host opens the Games panel.
/// Room UI stays visible above this sheet per the locked scope.
class GameSheet extends StatelessWidget {
  const GameSheet({super.key});

  static const games = [
    GameEntry(Icons.casino_rounded, 'Lucky Wheel'),
    GameEntry(Icons.local_florist_rounded, 'Fruit Party'),
    GameEntry(Icons.style_rounded, 'Slot'),
    GameEntry(Icons.donut_large_rounded, 'Lucky Wheel 77'),
    GameEntry(Icons.sports_soccer_rounded, 'Bounty Football'),
    GameEntry(Icons.sports_soccer_outlined, 'Football'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text('Game', style: AppTextStyles.heading(size: 15, color: AppColors.greenDarker)),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: games
                .map((g) => Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.greenLight, AppColors.greenMid],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: AppColors.green),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(g.icon, color: AppColors.greenDark, size: 22),
                          const SizedBox(height: 4),
                          Text(g.name,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.label(size: 9.5, color: AppColors.greenDarker)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
