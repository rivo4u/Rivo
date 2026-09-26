import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/rivo_api.dart';
import '../services/phone_image_upload.dart';
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

  String _value(List<String> keys, {String fallback = '—'}) {
    for (final key in keys) {
      final value = _profile?[key];
      if (value != null) return value.toString();
    }
    return fallback;
  }

  Future<void> _editProfile({XFile? selectedImage}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          profile: Map.of(_profile ?? {}),
          initialImage: selectedImage,
        ),
      ),
    );
    if (mounted && saved == true) await _loadProfile();
  }

  Future<void> _chooseAvatar() async {
    try {
      final image = await PhoneImageUpload(Supabase.instance.client).pick();
      if (mounted && image != null) await _editProfile(selectedImage: image);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not select profile photo: $error')),
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
                          if (_profile?.containsKey('vip_level') == true ||
                              _profile?.containsKey('svip_level') == true)
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
              InkWell(
                onTap: _chooseAvatar,
                customBorder: const CircleBorder(),
                child: AppAvatar(
                  label: _displayName,
                  size: 70,
                  imageUrl: _api.imageUrl(
                    _profile?['avatar_path'],
                    bucket: PhoneImageUpload.avatarsBucket,
                  ),
                ),
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
                    Text('Profile ID: ${_value(['public_id'])}',
                        style: AppTextStyles.label()),
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
          if ((_profile?['bio']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_profile!['bio'].toString(),
                  style: AppTextStyles.body(size: 13)),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _editProfile,
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Edit Profile'),
            ),
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
    final cards = <Widget>[
      if (_profile?.containsKey('vip_level') == true)
        Expanded(
          child: _vipCard('VIP ${_value(['vip_level'])}',
              Icons.favorite_rounded, AppColors.gradientVip),
        ),
      if (_profile?.containsKey('svip_level') == true)
        Expanded(
          child: _vipCard('SVIP ${_value(['svip_level'])}',
              Icons.diamond_rounded, AppColors.gradientSvip),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
      child: Row(children: [
        for (var index = 0; index < cards.length; index++) ...[
          if (index > 0) const SizedBox(width: 10),
          cards[index],
        ],
      ]),
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

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.profile,
    this.initialImage,
  });

  final Map<String, dynamic> profile;
  final XFile? initialImage;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _api = RivoApi(Supabase.instance.client);
  late final TextEditingController _name;
  late final TextEditingController _bio;
  XFile? _image;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _image = widget.initialImage;
    final metadata = Supabase.instance.client.auth.currentUser?.userMetadata;
    _name = TextEditingController(
      text: (widget.profile['display_name'] ??
              widget.profile['username'] ??
              metadata?['full_name'] ??
              metadata?['name'] ??
              '')
          .toString(),
    );
    _bio = TextEditingController(text: widget.profile['bio']?.toString() ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await PhoneImageUpload(Supabase.instance.client).pick();
      if (mounted && image != null) setState(() => _image = image);
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Could not open photo picker: $error');
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 40) {
      setState(() => _error = name.isEmpty
          ? 'Display name is required.'
          : 'Use 40 characters or fewer for the display name.');
      return;
    }
    if (_bio.text.trim().length > 160) {
      setState(() => _error = 'Use 160 characters or fewer for the bio.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final changes = <String, dynamic>{
        'display_name': name,
        'bio': _bio.text.trim(),
      };
      if (_image != null) {
        changes['avatar_path'] = await _api.uploadImage(
          _image!,
          bucket: PhoneImageUpload.avatarsBucket,
          path:
              '${Supabase.instance.client.auth.currentUser!.id}/avatar.jpg',
        );
      }
      await _api.updateMyProfile(changes);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted)
        setState(
            () => _error = 'Could not save. Tap Retry to try again. $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _name.text.isEmpty ? 'Rivo user' : _name.text;
    final existingPhoto = _api.imageUrl(
      widget.profile['avatar_path'],
      bucket: PhoneImageUpload.avatarsBucket,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Center(
              child: InkWell(
                onTap: _saving ? null : _pickImage,
                customBorder: const CircleBorder(),
                child: Stack(alignment: Alignment.bottomRight, children: [
                  _image != null
                      ? CircleAvatar(
                          radius: 48,
                          backgroundImage: FileImage(File(_image!.path)),
                        )
                      : AppAvatar(
                          label: displayName,
                          size: 96,
                          imageUrl: existingPhoto,
                        ),
                  const CircleAvatar(
                    radius: 16,
                    child: Icon(Icons.camera_alt_rounded, size: 17),
                  ),
                ]),
              ),
            ),
            Center(
              child: TextButton.icon(
                onPressed: _saving ? null : _pickImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(_image == null ? 'Choose photo' : 'Replace photo'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _name,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bio,
              maxLength: 160,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Bio',
                border: OutlineInputBorder(),
              ),
            ),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Profile ID',
                border: OutlineInputBorder(),
              ),
              child: Text(widget.profile['public_id']?.toString() ?? '—'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_error == null ? 'Save' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
