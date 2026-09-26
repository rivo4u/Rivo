import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/rivo_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common.dart';
import 'feature_screens.dart';

class PublicProfileScreen extends StatefulWidget {
  final String username;
  final String userId;

  const PublicProfileScreen(
      {super.key, this.username = 'ROYAL', this.userId = 'ROYAL'});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _api = RivoApi(Supabase.instance.client);
  int tabIndex = 0;
  final tabs = const ['Profile', 'Relation', 'Moments'];

  final tags = const [
    'Weekly Star Top1',
    'True Love Top2',
    'Pak King Top2',
    'Super Admin',
    'Sweet Love',
    'BD',
    'Agent',
    'Host',
    'BD Leader',
  ];

  final medalIcons = const [
    Icons.military_tech_rounded,
    Icons.pets_rounded,
    Icons.star_rounded,
    Icons.favorite_rounded,
    Icons.eco_rounded,
    Icons.shield_rounded,
    Icons.diamond_rounded,
    Icons.hexagon_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _header(),
                    _statsBox(),
                    _supporterCard(),
                    _tabs(),
                    _medals(),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _footer(),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: const BoxDecoration(gradient: AppColors.gradientSvip),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _circleBtn(Icons.arrow_back_rounded),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
                onSelected: _userAction,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'message', child: Text('Message')),
                  PopupMenuItem(value: 'block', child: Text('Block user')),
                  PopupMenuItem(value: 'report', child: Text('Report user')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          AppAvatar(label: widget.username, size: 84, ringColor: Colors.white),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.username,
                  style: AppTextStyles.heading(size: 19, color: Colors.white)),
              const SizedBox(width: 6),
              const Icon(Icons.emoji_events_rounded,
                  size: 16, color: Colors.amberAccent),
              const SizedBox(width: 6),
              const Icon(Icons.male_rounded, size: 16, color: Colors.white),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                  'ID: ${int.tryParse(widget.userId) != null ? widget.userId : '—'}',
                  style: AppTextStyles.body(size: 12.5, color: Colors.white70)),
              const SizedBox(width: 4),
              const Icon(Icons.copy_rounded, size: 13, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _levelPill(Icons.diamond_rounded, '—'),
              const SizedBox(width: 8),
              _levelPill(Icons.monetization_on_rounded, '—'),
              const SizedBox(width: 8),
              _levelPill(Icons.emoji_events_rounded, '—'),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: tags.map(_tagPill).toList(),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon) => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, size: 15, color: Colors.white),
      );

  Widget _levelPill(IconData icon, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Text(value,
                style: AppTextStyles.body(
                    size: 12.5, weight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      );

  Widget _tagPill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Text(label,
            style: AppTextStyles.label(size: 11, color: AppColors.greenDarker)
                .copyWith(fontWeight: FontWeight.w800)),
      );

  Widget _statsBox() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.greenLight,
        border: Border.all(color: AppColors.greenMid),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          StatColumn(
              value: '—', label: 'Friend', valueColor: AppColors.greenDarker),
          StatColumn(
              value: '—', label: 'Follow', valueColor: AppColors.greenDarker),
          StatColumn(
              value: '—', label: 'Fans', valueColor: AppColors.greenDarker),
          StatColumn(
              value: '—', label: 'Visitor', valueColor: AppColors.greenDarker),
        ],
      ),
    );
  }

  Widget _supporterCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(colors: [Color(0xFF8FE0A8), AppColors.green]),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Text('Supporter',
              style: AppTextStyles.heading(size: 15, color: Colors.white)),
          const Spacer(),
          SizedBox(
            width: 70,
            height: 34,
            child: Stack(
              children: List.generate(3, (i) {
                return Positioned(
                  left: i * 18.0,
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: AppColors.greenLight,
                      child: Text(String.fromCharCode(65 + i),
                          style: AppTextStyles.label(
                              size: 12, color: AppColors.greenDark)),
                    ),
                  ),
                );
              }),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ],
      ),
    );
  }

  Widget _tabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = i == tabIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 24),
            child: InkWell(
              onTap: () => setState(() => tabIndex = i),
              child: Container(
                padding: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? AppColors.green : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  tabs[i],
                  style: AppTextStyles.body(
                    size: 14,
                    weight: FontWeight.w700,
                    color: active ? AppColors.greenDark : AppColors.textMute,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _medals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text('Medal', style: AppTextStyles.heading(size: 15)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: medalIcons
                .map((icon) => Container(
                      decoration: BoxDecoration(
                        color: AppColors.greenLight,
                        border: Border.all(color: AppColors.greenMid),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, color: AppColors.greenDark, size: 24),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          _footAction(Icons.favorite_border_rounded, 'Follow',
              onTap: () => _userAction('follow')),
          const SizedBox(width: 18),
          _footAction(Icons.home_rounded, 'In room'),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              gradient: AppColors.gradientVip,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_add_alt_1_rounded,
                    size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text('Add friend',
                    style: AppTextStyles.body(
                        size: 14,
                        weight: FontWeight.w800,
                        color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _userAction(String action) async {
    if (widget.userId == Supabase.instance.client.auth.currentUser?.id) return;
    try {
      switch (action) {
        case 'follow':
          await _api.followUser(widget.userId);
          break;
        case 'block':
          await _api.blockUser(widget.userId);
          break;
        case 'report':
          final controller = TextEditingController();
          final reason = await showDialog<String>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Report user'),
                content: TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 500,
                    decoration: const InputDecoration(labelText: 'Reason')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      child: const Text('Submit')),
                ],
              );
            },
          );
          controller.dispose();
          if (reason == null || reason.isEmpty) return;
          await _api.reportUser(widget.userId, reason);
          break;
        case 'message':
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      DirectChatScreen(otherUserId: widget.userId)));
          return;
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${action[0].toUpperCase()}${action.substring(1)} submitted.')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not $action user: $error')));
    }
  }

  Widget _footAction(IconData icon, String label, {VoidCallback? onTap}) =>
      InkWell(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.greenDark),
              const SizedBox(height: 2),
              Text(label, style: AppTextStyles.label(size: 11)),
            ],
          ));
}
