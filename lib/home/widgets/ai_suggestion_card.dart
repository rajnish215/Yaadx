import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../reminder/reminder_controller.dart';
import '../../reminder/reminder_model.dart';
import '../../reminder/reminder_service.dart';
import '../../reminder/add_reminder_screen.dart';
import '../../suggestions/suggestion_service.dart';

class AiSuggestionCard extends StatefulWidget {
  const AiSuggestionCard({super.key});
  @override
  State<AiSuggestionCard> createState() => _AiSuggestionCardState();
}

class _AiSuggestionCardState extends State<AiSuggestionCard> {
  Timer? _timer;
  int _refresh = 0;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = context.watch<ReminderController>().nextEventForHome(
      DateTime.now(),
    );
    final uid = ReminderService().accountId;
    if (event == null || uid == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A little thought goes a long way ✨',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add an upcoming event to discover wishes and thoughtful gift ideas.',
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddReminderScreen()),
                ),
                child: const Text('Add an event'),
              ),
            ],
          ),
        ),
      );
    }
    final fingerprint =
        '${event.id}|${event.name}|${event.relation}|${event.eventType}|${event.date}|${DateTime.now().year}|$_refresh';
    return SuggestionPanel(
      key: ValueKey('$uid|$fingerprint'),
      uid: uid,
      event: event,
      onDetailsClosed: () {
        if (mounted) setState(() => _refresh++);
      },
    );
  }
}

class SuggestionPanel extends StatefulWidget {
  final String uid;
  final ReminderModel event;
  final bool expanded;
  final SuggestionService? service;
  final String? Function()? currentUid;
  final VoidCallback? onDetailsClosed;
  const SuggestionPanel({
    super.key,
    required this.uid,
    required this.event,
    this.expanded = false,
    this.service,
    this.currentUid,
    this.onDetailsClosed,
  });
  @override
  State<SuggestionPanel> createState() => _SuggestionPanelState();
}

class _SuggestionPanelState extends State<SuggestionPanel> {
  late final SuggestionService _service;
  SuggestionOptions _options = SuggestionOptions();
  Suggestion? _result;
  bool _busy = true;
  String? _error;
  int _request = 0;
  bool get _active =>
      mounted &&
      (widget.currentUid != null
              ? widget.currentUid!()
              : ReminderService().accountId) ==
          widget.uid;
  @override
  void initState() {
    super.initState();
    _service =
        widget.service ?? SuggestionService(cloud: ReminderService().cloud);
    _load();
  }

  Future<void> _load() async {
    try {
      _options = await _service.options(widget.uid, widget.event.id);
      if (!_active) return;
      await _generate();
    } catch (_) {
      if (_active) {
        setState(() {
          _busy = false;
          _error = 'Could not load saved preferences. Please retry.';
        });
      }
    }
  }

  Future<void> _generate({bool another = false}) async {
    if (!_active) return;
    final request = ++_request;
    if (another) _options.variant = (_options.variant + 1) % 1000000;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.saveOptions(widget.uid, widget.event.id, _options);
      if (!_active || request != _request) return;
      final result = await _service.generate(
        widget.uid,
        widget.event,
        _options,
      );
      if (!_active || request != _request) return;
      setState(() => _result = result);
    } catch (_) {
      if (_active) {
        setState(() => _error = 'Could not save suggestions. Please retry.');
      }
    } finally {
      if (_active && request == _request) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _copy() async {
    if (!_active) return;
    try {
      await Clipboard.setData(ClipboardData(text: _result!.wish));
      _message('Wish copied');
    } catch (_) {
      _message('Could not copy this wish.');
    }
  }

  Future<void> _edit() async {
    var edited = _result!.wish;
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Make it your own'),
        content: TextFormField(
          initialValue: edited,
          onChanged: (value) => edited = value,
          maxLength: 800,
          maxLines: 6,
          decoration: const InputDecoration(labelText: 'Your wish'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (edited.trim().isNotEmpty) {
                Navigator.pop(dialogContext, edited.trim());
              }
            },
            child: const Text('Use wish'),
          ),
        ],
      ),
    );
    if (text != null && _active) {
      setState(() => _busy = true);
      try {
        final edited = await _service.saveEdited(
          widget.uid,
          widget.event,
          _options,
          _result!,
          text,
        );
        if (_active) {
          setState(() => _result = edited);
          _message('Your wish is saved');
        }
      } catch (_) {
        if (_active) {
          setState(
            () => _result = Suggestion(
              text,
              _result!.gifts,
              ai: _result!.ai,
              edited: true,
              notice: 'Could not save this edit. Copy it before leaving.',
            ),
          );
        }
      } finally {
        if (_active) setState(() => _busy = false);
      }
    }
  }

  Future<void> _share() async {
    if (!_active) return;
    final box = context.findRenderObject() as RenderBox?;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: _result!.wish,
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      _message('Sharing is unavailable. You can copy the wish instead.');
    }
  }

  Future<void> _toggleAi(bool enabled) async {
    if (enabled) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          scrollable: true,
          title: const Text('Personalise with AI?'),
          content: const Text(
            'Google Gemini will receive this person’s name, event type, relationship, and the interests, budget and style you choose. Phone numbers, private notes, photos and recordings are not sent.\n\nWhen enabled, ideas generate automatically for upcoming events and are saved on this device. You can turn this off anytime. Offline ideas work without AI.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Keep offline'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Enable AI'),
            ),
          ],
        ),
      );
      if (accepted != true || !_active) return;
    }
    _options.ai = enabled;
    await _generate();
  }

  Widget _choice(
    String label,
    List<String> items,
    String value,
    ValueChanged<String> update,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      key: ValueKey("$label-$value"),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items
          .map(
            (v) => DropdownMenuItem(
              value: v,
              child: Text(
                label == 'Gift budget'
                    ? (v == 'Any' ? 'No budget preference' : 'Up to ₹$v')
                    : v,
              ),
            ),
          )
          .toList(),
      onChanged: _busy
          ? null
          : (v) {
              if (v != null) {
                update(v);
                _generate();
              }
            },
    ),
  );
  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xffFFF2F6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xffFFD7E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xffC8453A)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Wish & gift ideas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'For ${widget.event.name} · ${widget.event.eventType}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            r?.edited == true
                ? 'Edited by you'
                : r?.ai == true
                ? 'AI-generated · review before sharing'
                : 'Offline inspiration',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          if (_busy) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Preparing a little inspiration…'),
          ],
          if (_error != null) Text(_error!),
          if (r != null) ...[
            const SizedBox(height: 16),
            SelectableText(
              r.wish,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            if (r.notice != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  r.notice!,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _copy,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy wish'),
                ),
                if (widget.expanded) ...[
                  TextButton.icon(
                    onPressed: _busy ? null : _edit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                  ),
                  TextButton.icon(
                    onPressed: _busy ? null : _share,
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Share'),
                  ),
                ] else
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(
                                    title: const Text('Make their day'),
                                  ),
                                  body: SafeArea(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(16),
                                      child: SuggestionPanel(
                                        uid: widget.uid,
                                        event: widget.event,
                                        expanded: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                            widget.onDetailsClosed?.call();
                          },
                    child: const Text('Gift ideas & customise'),
                  ),
              ],
            ),
            const Divider(height: 24),
            ...r.gifts
                .take(widget.expanded ? 5 : 1)
                .map(
                  (g) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.card_giftcard,
                          color: Color(0xffC8453A),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                g.reason,
                                style: const TextStyle(height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
          if (widget.expanded) ...[
            const Text(
              'Ideas only; check prices and personal preferences before buying.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            _choice(
              'Language',
              ['Hinglish', 'Hindi', 'English'],
              _options.language,
              (v) => _options.language = v,
            ),
            _choice(
              'Tone',
              ['Warm', 'Funny', 'Short'],
              _options.tone,
              (v) => _options.tone = v,
            ),
            _choice(
              'Gift budget',
              ['Any', '500', '1000', '2500'],
              _options.budget,
              (v) => _options.budget = v,
            ),
            TextFormField(
              key: ValueKey("interests-${_options.interests}"),
              initialValue: _options.interests,
              maxLength: 160,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Interests (optional)',
                helperText: 'Tap More ideas to apply your interests.',
                hintText: 'Books, music, gardening…',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _options.interests = v,
              onFieldSubmitted: (_) => _generate(),
            ),
            Material(
              color: Colors.transparent,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use AI suggestions'),
                subtitle: const Text(
                  'Optional · personalise with Google Gemini',
                ),
                value: _options.ai,
                onChanged: _busy ? null : _toggleAi,
              ),
            ),
          ],
          TextButton.icon(
            onPressed: _busy ? null : () => _generate(another: _error == null),
            icon: const Icon(Icons.refresh),
            label: Text(_error != null ? 'Retry' : 'More ideas'),
          ),
        ],
      ),
    );
  }
}
