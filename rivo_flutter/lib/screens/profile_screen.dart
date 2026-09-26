import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/rivo_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common.dart';
import 'feature_screens.dart';

class ProfileScreen extends StatefulWidget {
  final String username;
  final String userId;
  final int visitors;
  final int following;
  final int followers;
  final bool showBottomNavigation;

  const ProfileScreen({
    super.key,
    this.username = '',
    this.userId = '',
    this.visitors = 0,
    this.following = 0,
    this.followers = 0,
    this.showBottomNavigation = true,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final RivoApi _api = RivoApi(Supabase.instance.client);
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _api.myProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _displayName {
    final metadata =
        Supabase.instance.client.auth.currentUser?.userMetadata ?? {};
    return (_profile?['display_name'] ??
            _profile?['username'] ??
            metadata['full_name'] ??
            metadata['name'] ??
            widget.username ??
            'Rivo user')
        .toString();
  }

  String get _userId =>
      Supabase.instance.client.auth.currentUser?.id ?? widget.userId;

  String _value(List<String> keys, {String fallback = '—'}) {
    for (final key in keys) {
      final value = _profile?[key];
      if (value != null) return value.toString();
    }
    return fallback;
  }

  Future<void> _editProfile() async {
    final keys = ['display_name', 'username', 'bio']
        .where((key) => _profile?.containsKey(key) ?? false)
        .toList();
    if (keys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No editable profile fields are available.')),
      );
      return;
    }
    final controllers = {
      for (final key in keys)
        key: TextEditingController(text: _profile![key]?.toString() ?? ''),
    };
    final changes = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final key in keys)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: controllers[key],
                    maxLength: key == 'bio' ? 160 : 40,
                    decoration: InputDecoration(
                      labelText: key.replaceAll('_', ' '),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              {for (final key in keys) key: controllers[key]!.text.trim()},
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
    if (changes == null) return;
    try {
      await _api.updateMyProfile(changes);
      await _loadProfile();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update profile: $error')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not sign out: $error')),
        );
      }
    }
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _onNavigationTap(int index) {
    if (index == 0) {
      Navigator.of(context).maybePop();
    } else if (index != 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This section is not connected yet.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _loading && _profile == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _profile == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _loadProfile,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadProfile,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _header(),
                          _vipRow(),
                          SectionCard(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                StatColumn(
                                    value: _value(['level']), label: 'Level'),
                                StatColumn(
                                    value: _value(['coins']), label: 'Coins'),
                                StatColumn(value: _value(['xp']), label: 'XP'),
                              ],
                            ),
                          ),
                          SectionCard(
                            child: GridView.count(
                              crossAxisCount: 4,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                GridIconItem(
                                    icon: Icons.account_balance_wallet_rounded,
                                    label: 'Wallet',
                                    onTap: () => _open(const WalletScreen())),
                                GridIconItem(
                                    icon: Icons.diamond_rounded,
                                    label: 'Diamond'),
                                GridIconItem(
                                    icon: Icons.storefront_rounded,
                                    label: 'Store'),
                                GridIconItem(
                                    icon: Icons.shopping_bag_rounded,
                                    label: 'Bag'),
                              ],
                            ),
                          ),
                          SectionCard(
                            child: GridView.count(
                              crossAxisCount: 4,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: 0.85,
                              children: [
                                GridIconItem(
                                    icon: Icons.badge_rounded,
                                    label: 'Host Center'),
                                GridIconItem(
                                    icon: Icons.workspace_premium_rounded,
                                    label: 'BD Center'),
                                GridIconItem(
                                    icon: Icons.favorite_rounded, label: 'CP'),
                                GridIconItem(
                                    icon: Icons.groups_rounded,
                                    label: 'Brother & Sister'),
                                GridIconItem(
                                    icon: Icons.flag_rounded, label: 'Family'),
                                GridIconItem(
                                    icon: Icons.emoji_events_rounded,
                                    label: 'Level'),
                                GridIconItem(
                                    icon: Icons.handshake_rounded,
                                    label: 'Close Friends'),
                                GridIconItem(
                                    icon: Icons.headset_mic_rounded,
                                    label: 'Contact us'),
                                GridIconItem(
                                    icon: Icons.settings_rounded,
                                    label: 'Settings',
                                    onTap: () => _open(const SettingsScreen())),
                                GridIconItem(
                                    icon: Icons.notifications_outlined,
                                    label: 'Notifications',
                                    onTap: () =>
                                        _open(const NotificationsScreen())),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
      ),
      bottomNavigationBar: widget.showBottomNavigation
          ? RivoBottomNav(currentIndex: 3, onTap: _onNavigationTap)
          : null,
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
      decoration: const BoxDecoration(gradient: AppColors.gradientHeader),
      child: Column(
        children: [
          Row(
            children: [
              AppAvatar(
                label: _displayName,
                size: 70,
                imageUrl: (_profile?['avatar_url'] ??
                        _profile?['avatar'] ??
                        Supabase.instance.client.auth.currentUser
                            ?.userMetadata?['picture'])
                    ?.toString(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.heading(size: 21),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.male_rounded,
                            size: 18, color: AppColors.green),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text('ID: $_userId', style: AppTextStyles.label()),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit profile',
                onPressed: _editProfile,
                icon: const Icon(Icons.edit_rounded, color: AppColors.textMute),
              ),
              IconButton(
                tooltip: 'Log out',
                onPressed: _signOut,
                icon:
                    const Icon(Icons.logout_rounded, color: AppColors.textMute),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StatColumn(value: _value(['visitors']), label: 'Visitors'),
              StatColumn(
                  value: _value(['following_count', 'following']),
                  label: 'Following'),
              StatColumn(
                  value: _value(['followers_count', 'followers']),
                  label: 'Followers'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vipRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
      child: Row(
        children: [
          Expanded(
              child: _vipCard('VIP ${_value(['vip_level'], fallback: '0')}',
                  Icons.favorite_rounded, AppColors.gradientVip)),
          const SizedBox(width: 10),
          Expanded(
              child: _vipCard('SVIP ${_value(['svip_level'], fallback: '0')}',
                  Icons.diamond_rounded, AppColors.gradientSvip)),
        ],
      ),
    );
  }

  Widget _vipCard(String label, IconData icon, Gradient gradient) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
          gradient: gradient, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTextStyles.heading(size: 19, color: Colors.white)
                  .copyWith(letterSpacing: 1)),
          CircleAvatar(
            radius: 15,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            child: Icon(icon, size: 14, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
