import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class RoomToolsSheet extends StatelessWidget {
  const RoomToolsSheet({super.key});

  static const tools = [
    (Icons.smart_display_rounded, 'YouTube'),
    (Icons.card_giftcard_rounded, 'Lucky Bag'),
    (Icons.workspace_premium_rounded, 'Super Winner'),
    (Icons.music_note_rounded, 'Music'),
    (Icons.sports_kabaddi_rounded, 'PK'),
    (Icons.settings_rounded, 'Setting'),
    (Icons.delete_sweep_rounded, 'Clear Message'),
    (Icons.auto_awesome_rounded, 'Effects'),
    (Icons.volume_off_rounded, 'Noise reduction'),
    (Icons.lock_rounded, 'Lock'),
    (Icons.mic_rounded, 'Mic'),
    (Icons.add_rounded, 'More'),
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
            child: Text('Room tools', style: AppTextStyles.heading(size: 15, color: AppColors.greenDarker)),
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 16,
            childAspectRatio: 0.8,
            children: tools
                .map((t) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.greenLight,
                            border: Border.all(color: AppColors.green),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Icon(t.$1, color: AppColors.greenDark, size: 20),
                        ),
                        const SizedBox(height: 6),
                        Text(t.$2,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.label(size: 9.5, color: AppColors.text)),
                      ],
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
