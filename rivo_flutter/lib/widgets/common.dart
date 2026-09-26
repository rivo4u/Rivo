import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Circular avatar with a storage-image renderer and initials fallback.
class AppAvatar extends StatelessWidget {
  final String label;
  final double size;
  final String? imageUrl;
  final Color ringColor;

  const AppAvatar({
    super.key,
    required this.label,
    this.size = 64,
    this.imageUrl,
    this.ringColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 3),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.green, AppColors.greenDark],
        ),
        boxShadow: AppShadows.sm,
      ),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorBuilder: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.green, AppColors.greenDark],
        ),
      ),
      child: Center(
        child: Text(
          label.isNotEmpty ? label[0].toUpperCase() : '?',
          style: AppTextStyles.heading(size: size * 0.36, color: Colors.white),
        ),
      ),
    );
  }
}

/// A white rounded card used for grouped grid sections (wallet/store/etc).
class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14).copyWith(top: 12),
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppShadows.sm,
      ),
      child: child,
    );
  }
}

/// A single number-over-label stat, used in profile headers and stat rows.
class StatColumn extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;
  final Color labelColor;

  const StatColumn({
    super.key,
    required this.value,
    required this.label,
    this.valueColor = AppColors.text,
    this.labelColor = AppColors.textMute,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.statNumber(color: valueColor)),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.label(color: labelColor)),
      ],
    );
  }
}

/// One icon-in-circle + caption tile, used in profile tool grids.
class GridIconItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const GridIconItem(
      {super.key, required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: AppColors.greenLight,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: AppColors.greenDark),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label(size: 10.5, color: AppColors.text)
                  .copyWith(height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared bottom navigation bar: Room / Moment / Message / Me.
class RivoBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const RivoBottomNav(
      {super.key, required this.currentIndex, required this.onTap});

  static const _items = [
    (icon: Icons.home_rounded, label: 'Room'),
    (icon: Icons.public_rounded, label: 'Moment'),
    (icon: Icons.chat_bubble_rounded, label: 'Message'),
    (icon: Icons.person_rounded, label: 'Me'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 74),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.cardBorder)),
          ),
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          child: Row(
            children: List.generate(_items.length, (i) {
              final active = i == currentIndex;
              final item = _items[i];
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: SizedBox(
                    height: 54,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.icon,
                            size: 20,
                            color: active
                                ? AppColors.greenDark
                                : AppColors.textMute),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: active
                                ? AppColors.greenDark
                                : AppColors.textMute,
                            fontWeight:
                                active ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
