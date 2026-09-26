import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../services/rivo_api.dart';
import '../widgets/common.dart';
import 'feature_screens.dart';
import 'profile_screen.dart';
import 'voice_room_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;
  final RivoApi _api = RivoApi(Supabase.instance.client);
  List<Map<String, dynamic>> _rooms = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rooms = await _api.activeRooms();
      debugPrint('Rivo active room query returned ${rooms.length} rows');
      if (mounted) setState(() => _rooms = rooms);
    } catch (error) {
      debugPrint('Rivo active room query failed: $error');
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _visibleRooms {
    return _rooms;
  }

  Future<void> _joinRoom(Map<String, dynamic> room) async {
    final roomId = room['id']?.toString();
    if (roomId == null) return;
    try {
      await _api.joinRoom(roomId);
    } catch (error) {
      debugPrint('Rivo room join failed for $roomId: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Room membership could not be updated: $error')),
        );
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VoiceRoomScreen(
          roomId: roomId,
          roomTitle: room['title']?.toString() ?? 'Voice room',
          hostId: room['owner_id']?.toString() ?? '',
        ),
      ),
    );
  }

  void _onNavigationTap(int index) {
    setState(() => _selectedTab = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 78),
              child: SafeArea(child: _selectedPage()),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: RivoBottomNav(
              currentIndex: _selectedTab,
              onTap: _onNavigationTap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedPage() {
    switch (_selectedTab) {
      case 0:
        return _roomList();
      case 1:
        return const MomentsScreen();
      case 2:
        return const MessagesScreen();
      case 3:
        return const ProfileScreen(showBottomNavigation: false);
      default:
        return _roomList();
    }
  }

  Widget _roomList() {
    if (_loading && _rooms.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _rooms.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 36, color: AppColors.textMute),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loadRooms,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final rooms = _visibleRooms;
    return RefreshIndicator(
      onRefresh: _loadRooms,
      child: rooms.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.24),
                Icon(Icons.meeting_room_outlined,
                    size: 42, color: AppColors.textMute),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'No active rooms yet.',
                    style: AppTextStyles.body(color: AppColors.textMute),
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 12),
              itemCount: rooms.length,
              itemBuilder: (_, index) => _roomCard(rooms[index]),
            ),
    );
  }

  Widget _roomCard(Map<String, dynamic> room) {
    final ownerId = room['owner_id']?.toString() ?? '';
    final title = room['title']?.toString() ?? 'Voice room';
    final description = room['description']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => _joinRoom(room),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.greenLight,
            border: Border.all(color: AppColors.green, width: 1.4),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(label: ownerId, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.heading(
                          size: 14, color: AppColors.greenDarker),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(description, style: AppTextStyles.label(size: 11)),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      ownerId.isEmpty
                          ? 'Host'
                          : 'Host ${ownerId.substring(0, ownerId.length.clamp(0, 8))}',
                      style: AppTextStyles.label(
                          size: 10, color: AppColors.textMute),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMute),
            ],
          ),
        ),
      ),
    );
  }
}
