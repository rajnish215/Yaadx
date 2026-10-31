import 'dart:async';
import 'package:flutter/material.dart';
import '../reminder/reminder_service.dart';
import 'cloud_api.dart';

/// The app inbox and support requests use the same authenticated cloud gateway
/// as reminders. Nothing from another account is kept on this screen.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with WidgetsBindingObserver {
  final _service = ReminderService();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  final _form = GlobalKey<FormState>();
  Map<String, dynamic>? _data;
  String? _owner;
  String? _error;
  String? _ticketId;
  bool _loading = false;
  bool _sending = false;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _owner = _service.accountId;
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _load();
      }
    });
  }

  bool get _sameAccount => _owner != null && _owner == _service.accountId;
  Future<void> _load() async {
    if (_loading || !mounted) return;
    if (!_sameAccount || _service.cloud == null) {
      setState(() {
        _data = null;
        _error = 'Sign in and connect to the YaadX backend to open your inbox.';
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await _service.cloud!.request(
        _owner!,
        'GET',
        '/v1/community',
      );
      if (mounted) {
        setState(() {
          _data = _sameAccount ? data : null;
          _error = _sameAccount ? null : 'Account changed. Reopen your inbox.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (!_sameAccount) _data = null;
          _error = e is CloudFailure && e.code == 'cloud_access_suspended'
              ? 'Cloud access is suspended. Contact YaadX support.'
              : 'Could not refresh your inbox. Check your connection and retry.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate() ||
        _sending ||
        !_sameAccount ||
        _service.cloud == null) {
      return;
    }
    setState(() => _sending = true);
    _ticketId ??= newOperationId();
    try {
      await _service.cloud!.request(_owner!, 'POST', '/v1/community/tickets', {
        'id': _ticketId!,
        'subject': _subject.text.trim(),
        'message': _message.text.trim(),
      });
      if (!mounted || !_sameAccount) return;
      _subject.clear();
      _message.clear();
      _ticketId = null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request sent. Replies will appear below.'),
        ),
      );
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not send. Retry shortly; your message is still here.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _read(Map item) async {
    if (!_sameAccount || _service.cloud == null) return;
    try {
      await _service.cloud!.request(
        _owner!,
        'POST',
        '/v1/community/announcements/${item['id']}/read',
      );
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not mark as read. Please retry.'),
          ),
        );
      }
    }
  }

  Future<void> _reply(String ticketId) async {
    if (!_sameAccount || _service.cloud == null) return;
    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SupportReplyDialog(
        ticketId: ticketId,
        uid: _owner!,
        service: _service,
      ),
    );
    if (mounted && _sameAccount && sent == true) await _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Widget _panel(Widget child) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );
  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.all(30),
    child: Center(child: Text(text, textAlign: TextAlign.center)),
  );
  @override
  Widget build(BuildContext context) {
    final data = _sameAccount ? _data : null;
    final announcements = (data?['announcements'] as List?) ?? [];
    final tickets = (data?['tickets'] as List?) ?? [];
    final settings = (data?['settings'] as Map?) ?? {};
    final plan = (data?['subscription'] as Map?) ?? {};
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab.clamp(0, 2),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('YaadX Inbox'),
          actions: [
            IconButton(
              tooltip: 'Refresh inbox',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Updates'),
              Tab(text: 'Support'),
              Tab(text: 'Plan'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
            Expanded(
              child: TabBarView(
                children: [
                  RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if ((settings['maintenance_message'] ?? '')
                            .toString()
                            .isNotEmpty)
                          _panel(Text(settings['maintenance_message'])),
                        if (announcements.isEmpty)
                          _empty(
                            'No announcements yet. Updates from YaadX will appear here.',
                          ),
                        for (final item in announcements)
                          _panel(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['title'] as String,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 10),
                                Text(item['body'] as String),
                                const SizedBox(height: 10),
                                if (item['is_read'] == true)
                                  const Text(
                                    'Read',
                                    style: TextStyle(color: Colors.grey),
                                  )
                                else
                                  TextButton(
                                    onPressed: () => _read(item as Map),
                                    child: const Text('Mark as read'),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if ((settings['support_email'] ?? '')
                            .toString()
                            .isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: SelectableText(
                              'Support: ${settings['support_email']}',
                            ),
                          ),
                        _panel(
                          Form(
                            key: _form,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'How can we help?',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _subject,
                                  enabled: !_sending,
                                  maxLength: 120,
                                  decoration: const InputDecoration(
                                    labelText: 'Subject',
                                  ),
                                  onChanged: (_) => _ticketId = null,
                                  validator: (v) => (v?.trim().length ?? 0) < 3
                                      ? 'Enter at least 3 characters'
                                      : null,
                                ),
                                TextFormField(
                                  controller: _message,
                                  enabled: !_sending,
                                  maxLength: 2000,
                                  minLines: 3,
                                  maxLines: 6,
                                  decoration: const InputDecoration(
                                    labelText: 'Describe your question',
                                  ),
                                  onChanged: (_) => _ticketId = null,
                                  validator: (v) => (v?.trim().length ?? 0) < 3
                                      ? 'Enter at least 3 characters'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed:
                                      _sending ||
                                          !_sameAccount ||
                                          _service.cloud == null
                                      ? null
                                      : _send,
                                  icon: const Icon(Icons.send),
                                  label: Text(
                                    _sending ? 'Sending…' : 'Send request',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          'Your requests',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        if (tickets.isEmpty)
                          _empty(
                            'Your support requests and admin replies will appear here.',
                          ),
                        for (final item in tickets)
                          _panel(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['subject'] as String,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(item['message'] as String),
                                const SizedBox(height: 8),
                                Text(
                                  'Status: ${(item['status'] as String).replaceAll('_', ' ')}',
                                ),
                                if (((item['messages'] as List?) ?? [])
                                        .isEmpty &&
                                    (item['reply'] as String).isNotEmpty) ...[
                                  const Divider(),
                                  const Text(
                                    'YaadX Support',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(item['reply'] as String),
                                ],
                                for (final message
                                    in (item['messages'] as List?) ?? []) ...[
                                  const Divider(),
                                  Text(
                                    message['author'] == 'admin'
                                        ? 'YaadX Support'
                                        : 'You',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(message['body'] as String),
                                ],
                                TextButton.icon(
                                  onPressed: () => _reply(item['id'] as String),
                                  icon: const Icon(Icons.reply),
                                  label: const Text('Add reply'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _panel(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.workspace_premium, size: 40),
                            const SizedBox(height: 16),
                            Text(
                              'Your plan: ${data == null ? 'Unavailable' : plan['plan'] ?? 'free'}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (plan['expires_at'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  'Plan expiry: ${plan['expires_at'].toString().split('T').first}',
                                ),
                              ),
                            const SizedBox(height: 16),
                            const Text(
                              'Plans are currently managed manually by YaadX. This screen does not start a paid subscription or charge you.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportReplyDialog extends StatefulWidget {
  const _SupportReplyDialog({
    required this.ticketId,
    required this.uid,
    required this.service,
  });
  final String ticketId, uid;
  final ReminderService service;
  @override
  State<_SupportReplyDialog> createState() => _SupportReplyDialogState();
}

class _SupportReplyDialogState extends State<_SupportReplyDialog> {
  final _text = TextEditingController();
  String? _operationId, _error;
  bool _busy = false;
  Future<void> _send() async {
    if (_busy || _text.text.trim().isEmpty) return;
    if (widget.service.accountId != widget.uid) {
      setState(() => _error = 'Account changed. Reopen your inbox.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    _operationId ??= newOperationId();
    try {
      await widget.service.cloud!.request(
        widget.uid,
        'POST',
        '/v1/community/tickets/${widget.ticketId}/messages',
        {'id': _operationId!, 'body': _text.text.trim()},
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not send your reply. Your text is preserved; please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Reply to YaadX Support'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _text,
              enabled: !_busy,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              onChanged: (_) => _operationId = null,
              decoration: const InputDecoration(labelText: 'Your message'),
            ),
            if (_error != null) Text(_error!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _send,
          child: Text(_busy ? 'Sending…' : 'Send reply'),
        ),
      ],
    ),
  );
}
