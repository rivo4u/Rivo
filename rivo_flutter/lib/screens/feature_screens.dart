import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../services/rivo_api.dart';
import '../services/phone_image_upload.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _api = RivoApi(Supabase.instance.client);
  late Future<_WalletData> _data;
  late Future<_RechargeData> _rechargeData;

  @override
  void initState() {
    super.initState();
    _data = _load();
    _rechargeData = _loadRechargeData();
  }

  Future<_WalletData> _load() async => _WalletData(
        await _api.myWallet(),
        await _api.coinTransactions(),
        await _api.giftHistory(),
        await _api.gifts(),
      );

  Future<_RechargeData> _loadRechargeData() async {
    final configFuture = _api.economyConfig();
    final packagesFuture = _api.rechargePackages();
    return _RechargeData(await configFuture, await packagesFuture);
  }

  void _refresh() => setState(() => _data = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: FutureBuilder<_WalletData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _errorState(snapshot.error, _refresh);
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!;
          final coins =
              _firstValue(data.wallet, ['coins', 'balance', 'coin_balance']) ??
                  '0';
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                      color: AppColors.greenLight,
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('COIN BALANCE'),
                        const SizedBox(height: 8),
                        Text(coins,
                            style: AppTextStyles.heading(
                                size: 32, color: AppColors.greenDarker)),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AddCoinsScreen())),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add coins'),
                        ),
                      ]),
                ),
                const SizedBox(height: 22),
                _rechargeSection(),
                const SizedBox(height: 22),
                Text('Gift history', style: AppTextStyles.heading(size: 17)),
                if (data.giftHistory.isEmpty)
                  const ListTile(title: Text('No gifts yet')),
                for (final gift in data.giftHistory)
                  _GiftHistoryTile(row: gift, catalog: data.catalog),
                const SizedBox(height: 18),
                Text('Coin transactions',
                    style: AppTextStyles.heading(size: 17)),
                if (data.transactions.isEmpty)
                  const ListTile(title: Text('No transactions yet')),
                for (final transaction in data.transactions)
                  _TransactionTile(row: transaction),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _rechargeSection() => FutureBuilder<_RechargeData>(
        future: _rechargeData,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recharge packages',
                    style: AppTextStyles.heading(size: 17)),
                const SizedBox(height: 8),
                Text('Could not load backend recharge configuration.'),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _rechargeData = _loadRechargeData()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final rate = _firstValue(data.config, ['usd_to_coins']);
          final minimum = _firstValue(
              data.config, ['min_recharge_usd', 'minimum_recharge_usd']);
          final maximum = _firstValue(
              data.config, ['max_recharge_usd', 'maximum_recharge_usd']);
          final packages = data.packages
              .where((row) => row['is_active'] != false && row['active'] != false)
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recharge packages',
                  style: AppTextStyles.heading(size: 17)),
              if (rate != null) ...[
                const SizedBox(height: 6),
                Text('Backend rate: $rate coins per USD'),
              ],
              if (minimum != null || maximum != null) ...[
                const SizedBox(height: 3),
                Text('Limits: ${minimum ?? '—'} to ${maximum ?? '—'} USD'),
              ],
              if (packages.isEmpty)
                const ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('No recharge packages are available.'))
              else
                for (final package in packages) _rechargePackage(package),
              const SizedBox(height: 4),
              Text(
                'Payments are not configured. No recharge will be submitted or coins added.',
                style: AppTextStyles.label(color: AppColors.textMute),
              ),
            ],
          );
        },
      );

  Widget _rechargePackage(Map<String, dynamic> package) {
    final label = _firstValue(
            package, ['name', 'title', 'label', 'package_name']) ??
        'Recharge package';
    final usd = _firstValue(
        package, ['usd_amount', 'amount_usd', 'price_usd', 'usd']);
    final coins = _firstValue(
        package, ['coins', 'coin_amount', 'coins_amount', 'amount_coins']);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text([
        if (usd != null) '\$$usd USD',
        if (coins != null) '$coins coins',
      ].join(' · ')),
      trailing: TextButton(
        onPressed: () => _showError(
          context,
          'Payment provider not configured. No recharge was created.',
        ),
        child: const Text('Unavailable'),
      ),
    );
  }
}

class _WalletData {
  const _WalletData(
      this.wallet, this.transactions, this.giftHistory, this.catalog);
  final Map<String, dynamic>? wallet;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> giftHistory;
  final List<Map<String, dynamic>> catalog;
}

class _RechargeData {
  const _RechargeData(this.config, this.packages);
  final Map<String, dynamic>? config;
  final List<Map<String, dynamic>> packages;
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final amount = _firstValue(row, ['amount', 'coin_amount', 'coins']) ?? '?';
    final kind =
        _firstValue(row, ['transaction_type', 'type', 'description']) ??
            'Coin transaction';
    final status = _firstValue(row, ['status', 'transaction_status']) ??
      'Status unavailable';
    return ListTile(
      leading: const Icon(Icons.toll_rounded, color: AppColors.greenDark),
      title: Text(kind.toString()),
      trailing: Text('$amount coins',
          style: AppTextStyles.body(weight: FontWeight.w700)),
        subtitle: Text('$status · ${_dateText(row['created_at'])}'),
    );
  }
}

class _GiftHistoryTile extends StatelessWidget {
  const _GiftHistoryTile({required this.row, required this.catalog});
  final Map<String, dynamic> row;
  final List<Map<String, dynamic>> catalog;

  @override
  Widget build(BuildContext context) {
    final sender = row['sender_id']?.toString() ?? 'Unknown';
    final receiver = row['receiver_id']?.toString() ?? 'Unknown';
    final giftId = row['gift_id']?.toString();
    final gift =
        catalog.where((item) => item['id']?.toString() == giftId).firstOrNull;
    final giftName =
        _firstValue(gift, ['name', 'title', 'gift_name']) ?? giftId;
    final amount = _firstValue(row, ['coin_amount', 'price', 'amount']) ?? '?';
    final self = Supabase.instance.client.auth.currentUser?.id;
    return ListTile(
      leading:
          const Icon(Icons.card_giftcard_rounded, color: AppColors.greenDark),
      title: Text('${giftName ?? 'Gift'} · $amount coins'),
      subtitle: Text(sender == self
          ? 'Sent to $receiver · ${_dateText(row['created_at'])}'
          : 'Received from $sender · ${_dateText(row['created_at'])}'),
    );
  }
}

class AddCoinsScreen extends StatelessWidget {
  const AddCoinsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Add coins')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.account_balance_wallet_outlined,
                  size: 48, color: AppColors.textMute),
              SizedBox(height: 14),
              Text('Coin purchases are unavailable',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              Text(
                  'A verified payment provider is not configured for this app. No coins have been added.',
                  textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
}

class MomentsScreen extends StatefulWidget {
  const MomentsScreen({super.key});

  @override
  State<MomentsScreen> createState() => _MomentsScreenState();
}

class _MomentsScreenState extends State<MomentsScreen> {
  final _api = RivoApi(Supabase.instance.client);
  late Future<List<Map<String, dynamic>>> _moments;

  @override
  void initState() {
    super.initState();
    _moments = _api.moments();
  }

  Future<void> _compose() async {
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateMomentScreen()),
    );
    if (mounted && posted == true) setState(() => _moments = _api.moments());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Moments')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _compose,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create Moment'),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _moments,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return _errorState(snapshot.error,
                  () => setState(() => _moments = _api.moments()));
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.data!.isEmpty)
              return const Center(child: Text('No Moments yet.'));
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final row = snapshot.data![index];
                final author = row['author'] as Map<String, dynamic>?;
                final own = row['user_id'] ==
                    Supabase.instance.client.auth.currentUser?.id;
                final imageUrl = _api.imageUrl(
                  author?['avatar_path'],
                  bucket: PhoneImageUpload.avatarsBucket,
                );
                final momentImage = _api.imageUrl(
                  row['image_path'],
                  bucket: PhoneImageUpload.momentsBucket,
                );
                return Card(
                  margin: const EdgeInsets.fromLTRB(12, 7, 12, 3),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          AppAvatar(
                            label: author?['display_name']?.toString() ?? 'R',
                            size: 42,
                            imageUrl: imageUrl,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  author?['display_name']?.toString() ??
                                      'Rivo user',
                                  style: AppTextStyles.body(
                                      weight: FontWeight.w700),
                                ),
                                Text(_dateText(row['created_at']),
                                    style: AppTextStyles.label()),
                              ],
                            ),
                          ),
                          if (own)
                            IconButton(
                              tooltip: 'Delete Moment',
                              onPressed: () => _deleteMoment(row),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                        ]),
                        if ((row['body'] ?? row['content'])
                            .toString()
                            .isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text((row['body'] ?? row['content']).toString()),
                        ],
                        if (momentImage != null) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              momentImage,
                              width: double.infinity,
                              height: 240,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox(
                                height: 90,
                                child: Center(
                                    child: Icon(Icons.broken_image_outlined)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      );

  Future<void> _deleteMoment(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return;
    try {
      await _api.deleteMoment(id);
      if (mounted) setState(() => _moments = _api.moments());
    } catch (error) {
      if (mounted) _showError(context, 'Could not delete Moment: $error');
    }
  }
}

class CreateMomentScreen extends StatefulWidget {
  const CreateMomentScreen({super.key});

  @override
  State<CreateMomentScreen> createState() => _CreateMomentScreenState();
}

class _CreateMomentScreenState extends State<CreateMomentScreen> {
  final _api = RivoApi(Supabase.instance.client);
  final _controller = TextEditingController();
  final _momentId = const Uuid().v4();
  Map<String, dynamic>? _profile;
  XFile? _image;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _api.myProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      // Posting remains available when the profile lookup is unavailable.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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

  Future<void> _post() async {
    final body = _controller.text.trim();
    if (body.isEmpty) {
      setState(() => _error = 'Write something before posting.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _api.createMoment(body, image: _image, momentId: _momentId);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted)
        setState(
            () => _error = 'Could not post. Tap Retry to try again. $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = _profile?['display_name']?.toString() ??
      _profile?['username']?.toString() ??
      user?.userMetadata?['full_name']?.toString() ??
        user?.userMetadata?['name']?.toString() ??
        'Rivo user';
    return Scaffold(
      appBar: AppBar(title: const Text('Create Moment')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              AppAvatar(
                label: name,
                size: 44,
                imageUrl: _api.imageUrl(
                  _profile?['avatar_path'],
                  bucket: PhoneImageUpload.avatarsBucket,
                ),
              ),
              const SizedBox(width: 12),
              Text(name, style: AppTextStyles.body(weight: FontWeight.w700)),
            ]),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              minLines: 4,
              maxLines: 8,
              maxLength: 1000,
              decoration: const InputDecoration(
                hintText: "What's happening?",
                border: OutlineInputBorder(),
              ),
            ),
            if (_image != null) ...[
              const SizedBox(height: 12),
              Stack(alignment: Alignment.topRight, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(_image!.path),
                      width: double.infinity, height: 240, fit: BoxFit.cover),
                ),
                IconButton.filledTonal(
                  onPressed:
                      _saving ? null : () => setState(() => _image = null),
                  icon: const Icon(Icons.close_rounded),
                ),
              ]),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(_image == null ? 'Add photo' : 'Replace photo'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _saving ? null : _post,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_error == null ? 'Post' : 'Retry'),
            ),
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _api = RivoApi(Supabase.instance.client);
  final _name = TextEditingController();
  final _bio = TextEditingController();
  XFile? _image;
  bool _saving = false;
  String? _error;

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

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 60) {
      setState(() => _error =
          name.isEmpty ? 'Enter a room name.' : 'Use 60 characters or fewer.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final room = await _api.createRoom(
        title: name,
        description: _bio.text.trim(),
        image: _image,
      );
      if (mounted) Navigator.of(context).pop(room);
    } catch (error) {
      if (mounted)
        setState(() =>
            _error = 'Could not create room. Tap Retry to try again. $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Create Room')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: InkWell(
                  onTap: _saving ? null : _pickImage,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 150,
                    height: 120,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.greenLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _image == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, size: 30),
                              SizedBox(height: 6),
                              Text('Room photo'),
                            ],
                          )
                        : Image.file(File(_image!.path), fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _saving ? null : _pickImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(_image == null ? 'Choose photo' : 'Replace photo'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Room name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bio,
                maxLength: 240,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Room bio (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _create,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_error == null ? 'Create Room' : 'Retry'),
              ),
            ],
          ),
        ),
      );
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _api = RivoApi(Supabase.instance.client);
  late Future<List<Map<String, dynamic>>> _messages;

  @override
  void initState() {
    super.initState();
    _messages = _api.directMessages();
  }

  Future<void> _startConversation() async {
    final controller = TextEditingController();
    final userId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New message'),
        content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Recipient user ID')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Open'))
        ],
      ),
    );
    controller.dispose();
    if (userId == null ||
        userId.isEmpty ||
        userId == Supabase.instance.client.auth.currentUser?.id ||
        !mounted) return;
    await _openChat(userId);
  }

  Future<void> _openChat(String userId) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => DirectChatScreen(otherUserId: userId)));
    if (mounted) setState(() => _messages = _api.directMessages());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Messages'), actions: [
          IconButton(
              tooltip: 'New message',
              onPressed: _startConversation,
              icon: const Icon(Icons.edit_square))
        ]),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _messages,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return _errorState(snapshot.error,
                  () => setState(() => _messages = _api.directMessages()));
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final currentId = Supabase.instance.client.auth.currentUser?.id;
            final latest = <String, Map<String, dynamic>>{};
            final unreadCounts = <String, int>{};
            for (final row in snapshot.data!) {
              final sender = row['sender_id']?.toString();
              final receiver = row['receiver_id']?.toString();
              final other = sender == currentId ? receiver : sender;
              if (other != null && other.isNotEmpty)
                latest.putIfAbsent(other, () => row);
              final readFlag = row['is_read'] ?? row['read'];
              final hasUnreadFlag = readFlag == false ||
                  (row.containsKey('read_at') && row['read_at'] == null);
              if (receiver == currentId && hasUnreadFlag && other != null) {
                unreadCounts.update(other, (count) => count + 1,
                    ifAbsent: () => 1);
              }
            }
            if (latest.isEmpty)
              return const Center(child: Text('No conversations yet.'));
            return ListView(children: [
              for (final entry in latest.entries)
                ListTile(
                  leading:
                      const CircleAvatar(child: Icon(Icons.person_rounded)),
                  title: Text(entry.key,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(entry.value['body']?.toString() ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_dateText(entry.value['created_at'])),
                        if ((unreadCounts[entry.key] ?? 0) > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                                color: AppColors.greenDark,
                                borderRadius: BorderRadius.circular(10)),
                            child: Text('${unreadCounts[entry.key]}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10)),
                          ),
                      ]),
                  onTap: () => _openChat(entry.key),
                ),
            ]);
          },
        ),
      );
}

class DirectChatScreen extends StatefulWidget {
  const DirectChatScreen({super.key, required this.otherUserId});
  final String otherUserId;

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final _api = RivoApi(Supabase.instance.client);
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _markIncomingRead();
  }

  Future<void> _markIncomingRead() async {
    try {
      await _api.markDirectMessagesRead(widget.otherUserId);
    } catch (error) {
      if (mounted) _showError(context, 'Could not mark messages as read: $error');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _api.sendDirectMessage(widget.otherUserId, body);
      _controller.clear();
    } catch (error) {
      if (mounted) _showError(context, 'Could not send message: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _userAction(String action) async {
    try {
      switch (action) {
        case 'follow':
          await _api.followUser(widget.otherUserId);
          break;
        case 'block':
          await _api.blockUser(widget.otherUserId);
          break;
        case 'report':
          final controller = TextEditingController();
          final reason = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
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
            ),
          );
          controller.dispose();
          if (reason == null || reason.isEmpty) return;
          await _api.reportUser(widget.otherUserId, reason);
          break;
      }
      if (mounted)
        _showError(context,
            '${action[0].toUpperCase()}${action.substring(1)} submitted.');
    } catch (error) {
      if (mounted) _showError(context, 'Could not $action user: $error');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.otherUserId,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'User actions',
              onSelected: _userAction,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'follow', child: Text('Follow')),
                PopupMenuItem(value: 'block', child: Text('Block')),
                PopupMenuItem(value: 'report', child: Text('Report')),
              ],
            ),
          ],
        ),
        body: Column(children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _api.watchDirectMessages(widget.otherUserId),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return _errorState(snapshot.error, () => setState(() {}));
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final rows = snapshot.data!;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients)
                    _scroll.jumpTo(_scroll.position.maxScrollExtent);
                });
                return ListView.builder(
                  controller: _scroll,
                  itemCount: rows.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final mine = row['sender_id'] ==
                        Supabase.instance.client.auth.currentUser?.id;
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 300),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                            color: mine ? AppColors.greenLight : Colors.white,
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(row['body']?.toString() ?? ''),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Message',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    )),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send_rounded),
                  color: AppColors.greenDark,
                  tooltip: 'Send',
                ),
              ]),
            ),
          ),
        ]),
      );
}
