import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/rivo_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _api = RivoApi(Supabase.instance.client);
  late Future<_WalletData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_WalletData> _load() async => _WalletData(
        await _api.myWallet(),
        await _api.coinTransactions(),
        await _api.giftHistory(),
        await _api.gifts(),
      );

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
}

class _WalletData {
  const _WalletData(
      this.wallet, this.transactions, this.giftHistory, this.catalog);
  final Map<String, dynamic>? wallet;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> giftHistory;
  final List<Map<String, dynamic>> catalog;
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
    return ListTile(
      leading: const Icon(Icons.toll_rounded, color: AppColors.greenDark),
      title: Text(kind.toString()),
      trailing: Text('$amount coins',
          style: AppTextStyles.body(weight: FontWeight.w700)),
      subtitle: Text(_dateText(row['created_at'])),
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
    final controller = TextEditingController();
    final body = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Moment'),
        content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 1000,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'Share an update')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Post'))
        ],
      ),
    );
    controller.dispose();
    if (body == null || body.isEmpty) return;
    try {
      await _api.createMoment(body);
      if (mounted) setState(() => _moments = _api.moments());
    } catch (error) {
      if (mounted) _showError(context, 'Could not post Moment: $error');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Moments')),
        floatingActionButton: FloatingActionButton(
            onPressed: _compose, child: const Icon(Icons.edit_rounded)),
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
                return ListTile(
                  leading:
                      const CircleAvatar(child: Icon(Icons.person_rounded)),
                  title: Text(row['user_id']?.toString() ?? 'Rivo user',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      '${row['body'] ?? ''}\n${_dateText(row['created_at'])}'),
                  isThreeLine: true,
                );
              },
            );
          },
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
                        enabled: !_sending,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                            hintText: 'Message',
                            border: OutlineInputBorder()))),
                IconButton(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded)),
              ]),
            ),
          ),
        ]),
      );
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = RivoApi(Supabase.instance.client);
  late Future<List<Map<String, dynamic>>> _rows;

  @override
  void initState() {
    super.initState();
    _rows = _api.notifications();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _rows,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return _errorState(snapshot.error,
                  () => setState(() => _rows = _api.notifications()));
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.data!.isEmpty)
              return const Center(child: Text('You are all caught up.'));
            return ListView(children: [
              for (final row in snapshot.data!)
                ListTile(
                  leading: const Icon(Icons.notifications_none_rounded,
                      color: AppColors.greenDark),
                  title: Text(_firstValue(row, ['title', 'type'])?.toString() ??
                      'Notification'),
                  subtitle: Text('${_firstValue(row, [
                            'body',
                            'message',
                            'content'
                          ]) ?? ''}\n${_dateText(row['created_at'])}'),
                  isThreeLine: true,
                ),
            ]);
          },
        ),
      );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _api = RivoApi(Supabase.instance.client);
  Map<String, dynamic>? _settings;
  Object? _error;
  bool _loading = true;
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await _api.mySettings();
      if (mounted)
        setState(() => _settings = settings ??
            {'user_id': Supabase.instance.client.auth.currentUser?.id});
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _change(String key, bool value) async {
    setState(() {
      _settings![key] = value;
      _saving.add(key);
    });
    try {
      await _api.updateMySettings({key: value});
    } catch (error) {
      if (mounted) {
        setState(() => _settings![key] = !value);
        _showError(context, 'Could not save setting: $error');
      }
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final boolFields =
        (_settings?.entries ?? const <MapEntry<String, dynamic>>[])
            .where((entry) => entry.value is bool && entry.key != 'user_id')
            .toList();
    final privacy = boolFields
        .where((entry) =>
            entry.key.toLowerCase().contains('private') ||
            entry.key.toLowerCase().contains('online') ||
            entry.key.toLowerCase().contains('message'))
        .toList();
    final notification = boolFields
        .where((entry) => entry.key.toLowerCase().contains('notif'))
        .toList();
    final other = boolFields
        .where((entry) =>
            !privacy.contains(entry) && !notification.contains(entry))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorState(_error, _load)
              : ListView(children: [
                  _settingsSection('Privacy', privacy),
                  _settingsSection('Notifications', notification),
                  _settingsSection('Account', other),
                  if (boolFields.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                            'No configurable privacy or notification fields were returned by user_settings.')),
                  ListTile(
                      leading: const Icon(Icons.notifications_outlined),
                      title: const Text('Notifications'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const NotificationsScreen()))),
                  ListTile(
                      leading: const Icon(Icons.logout_rounded),
                      title: const Text('Log out'),
                      onTap: () => Supabase.instance.client.auth.signOut()),
                ]),
    );
  }

  Widget _settingsSection(
      String title, List<MapEntry<String, dynamic>> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
          child: Text(title, style: AppTextStyles.heading(size: 16))),
      for (final entry in entries)
        SwitchListTile(
          title: Text(entry.key.replaceAll('_', ' ')),
          value: entry.value as bool,
          onChanged: _saving.contains(entry.key)
              ? null
              : (value) => _change(entry.key, value),
        ),
    ]);
  }
}

class GiftSendSheet extends StatefulWidget {
  const GiftSendSheet(
      {super.key, required this.roomId, required this.recipients});
  final String roomId;
  final List<Map<String, dynamic>> recipients;

  @override
  State<GiftSendSheet> createState() => _GiftSendSheetState();
}

class _GiftSendSheetState extends State<GiftSendSheet> {
  final _api = RivoApi(Supabase.instance.client);
  late Future<_GiftData> _data;
  String? _recipientId;
  String? _giftId;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_GiftData> _load() async =>
      _GiftData(await _api.gifts(), await _api.myWallet());

  Future<void> _send() async {
    if (_recipientId == null || _giftId == null || _sending) return;
    setState(() => _sending = true);
    try {
      await _api.sendGift(
          receiverId: _recipientId!, giftId: _giftId!, roomId: widget.roomId);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showError(context, 'Could not send gift: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              18, 18, 18, 18 + MediaQuery.viewInsetsOf(context).bottom),
          child: FutureBuilder<_GiftData>(
            future: _data,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return SizedBox(
                    height: 240,
                    child: _errorState(
                        snapshot.error, () => setState(() => _data = _load())));
              if (!snapshot.hasData)
                return const SizedBox(
                    height: 240,
                    child: Center(child: CircularProgressIndicator()));
              final data = snapshot.data!;
              final gifts = data.gifts;
              final balance = _firstValue(
                      data.wallet, ['coins', 'balance', 'coin_balance']) ??
                  '0';
              return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Text('Send a gift',
                          style: AppTextStyles.heading(size: 18)),
                      const Spacer(),
                      Text('$balance coins')
                    ]),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _recipientId,
                      decoration: const InputDecoration(labelText: 'Receiver'),
                      items: widget.recipients.map((row) {
                        final id = row['user_id']!.toString();
                        return DropdownMenuItem(
                            value: id,
                            child: Text(row['label']?.toString() ?? id));
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _recipientId = value),
                    ),
                    const SizedBox(height: 10),
                    if (gifts.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No gifts are available.')),
                    if (gifts.isNotEmpty)
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: gifts.length,
                          itemBuilder: (context, index) {
                            final gift = gifts[index];
                            final id = gift['id']?.toString();
                            final name = _firstValue(
                                    gift, ['name', 'title', 'gift_name']) ??
                                'Gift';
                            final price = _firstValue(
                                    gift, ['price', 'coin_price', 'coins']) ??
                                '?';
                            final selected = id != null && _giftId == id;
                            return ListTile(
                              onTap: id == null
                                  ? null
                                  : () => setState(() => _giftId = id),
                              leading: Icon(
                                  selected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  color: AppColors.greenDark),
                              title: Text(name.toString()),
                              subtitle: Text('$price coins'),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                        onPressed:
                            _sending || _recipientId == null || _giftId == null
                                ? null
                                : _send,
                        icon: const Icon(Icons.card_giftcard_rounded),
                        label: Text(_sending ? 'Sending...' : 'Send gift')),
                  ]);
            },
          ),
        ),
      );
}

class _GiftData {
  const _GiftData(this.gifts, this.wallet);
  final List<Map<String, dynamic>> gifts;
  final Map<String, dynamic>? wallet;
}

String? _firstValue(Map<String, dynamic>? row, List<String> keys) {
  if (row == null) return null;
  for (final key in keys) {
    final value = row[key];
    if (value != null) return value.toString();
  }
  return null;
}

String _dateText(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (parsed == null) return '';
  return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
}

Widget _errorState(Object? error, VoidCallback retry) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Could not load data: $error', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry')),
        ]),
      ),
    );

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
