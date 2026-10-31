
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../../reminder/reminder_controller.dart';
import '../../reminder/reminder_model.dart';

class TaskSection extends StatelessWidget {
  const TaskSection({super.key});

  static const Color _accent = Color(0xffF25F5C);

  @override
  Widget build(BuildContext context) {
    return Consumer<ReminderController>(
      builder: (context, controller, child) {
        final upcoming = controller.upcomingReminders;

        if (upcoming.isEmpty) {
          return _buildEmptyState();
        }

        final reminder = upcoming.first;

        final photoDone = reminder.memoryPhotoPaths.any(
          (path) => File(path).existsSync(),
        );

        final descriptionDone = reminder.memoryCaption.trim().isNotEmpty;

        final voicePath = reminder.voiceNotePath;
        final voiceDone = reminder.voiceNoteCompleted &&
            voicePath != null &&
            File(voicePath).existsSync();

        final completedCount = [
          photoDone,
          descriptionDone,
          voiceDone,
          reminder.messageSent,
        ].where((done) => done).length;

        final progress = completedCount / 4;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Event Preparation',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xffFFE7E5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${reminder.eventType} • ${reminder.name}',
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(_accent),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$completedCount of 4 tasks completed',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xffFFE7E5),
                  width: 1.2,
                ),
              ),
              child: Column(
                children: [
                  _buildChecklistItem(
                    title: 'Upload a photo',
                    subtitle: photoDone
                        ? 'Photo saved successfully'
                        : 'Add a memory photo for this event',
                    completed: photoDone,
                  ),
                  _buildDivider(),
                  _buildChecklistItem(
                    title: 'Write a description',
                    subtitle: descriptionDone
                        ? 'Description saved'
                        : 'Write a caption or personal message',
                    completed: descriptionDone,
                  ),
                  _buildDivider(),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: _VoiceNoteRecorder(
                      key: ValueKey('voice_${reminder.id}'),
                      reminder: reminder,
                    ),
                  ),
                  _buildDivider(),
                  _buildSendTask(context, reminder, controller),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChecklistItem({
    required String title,
    required String subtitle,
    required bool completed,
  }) {
    return CheckboxListTile(
      value: completed,
      onChanged: null,
      activeColor: _accent,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 5,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: completed ? Colors.grey.shade500 : Colors.black87,
          decoration:
              completed ? TextDecoration.lineThrough : TextDecoration.none,
        ),
      ),
      subtitle: Text(subtitle),
    );
  }

  Widget _buildSendTask(
    BuildContext context,
    ReminderModel reminder,
    ReminderController controller,
  ) {
    return CheckboxListTile(
      value: reminder.messageSent,
      onChanged: (value) async {
        if (value == null) return;

        try {
          await controller.updateReminder(
            reminder.copyWith(messageSent: value),
          );
        } catch (_) {
          if (!context.mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not save checklist status.'),
            ),
          );
        }
      },
      activeColor: _accent,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 5,
      ),
      title: Text(
        'Send to ${reminder.name}',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: reminder.messageSent ? Colors.grey.shade500 : Colors.black87,
          decoration: reminder.messageSent
              ? TextDecoration.lineThrough
              : TextDecoration.none,
        ),
      ),
      subtitle: Text(
        reminder.messageSent
            ? 'Marked as sent'
            : 'Mark complete after sending your message',
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: const Color(0xffFFE7E5).withValues(alpha: 0.5),
      indent: 18,
      endIndent: 18,
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xffFFE7E5)),
      ),
      child: const Column(
        children: [
          Icon(Icons.checklist_rounded, size: 42, color: _accent),
          SizedBox(height: 10),
          Text(
            'No upcoming event',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Add a reminder to start preparing.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _VoiceNoteRecorder extends StatefulWidget {
  final ReminderModel reminder;

  const _VoiceNoteRecorder({
    super.key,
    required this.reminder,
  });

  @override
  State<_VoiceNoteRecorder> createState() => _VoiceNoteRecorderState();
}

class _VoiceNoteRecorderState extends State<_VoiceNoteRecorder> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    });
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();

      if (!hasPermission) {
        _showMessage('Please allow microphone permission.');
        return;
      }

      final appDirectory = await getApplicationDocumentsDirectory();
      final voiceDirectory =
          Directory('${appDirectory.path}/yaadx_voice_notes');

      await voiceDirectory.create(recursive: true);

      final path =
          '${voiceDirectory.path}/voice_${widget.reminder.id}_'
          '${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      if (!mounted) return;
      setState(() => _isRecording = true);
    } catch (error) {
      _showMessage('Could not start recording: $error');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();

      if (path == null || !await File(path).exists()) {
        if (!mounted) return;
        setState(() => _isRecording = false);
        _showMessage('Recording file was not created.');
        return;
      }

      if (!mounted) return;
      final controller = context.read<ReminderController>();

      await controller.updateReminder(
        widget.reminder.copyWith(
          voiceNotePath: path,
          voiceNoteCompleted: true,
        ),
      );

      if (!mounted) return;

      setState(() => _isRecording = false);
      _showMessage('Voice note saved successfully.');
    } catch (error) {
      _showMessage('Could not save voice note: $error');
    }
  }

  Future<void> _togglePlayback() async {
    final path = widget.reminder.voiceNotePath;

    if (path == null || !await File(path).exists()) {
      _showMessage('Voice note file not found.');
      return;
    }

    try {
      if (_isPlaying) {
        await _player.stop();

        if (!mounted) return;
        setState(() => _isPlaying = false);
      } else {
        await _player.play(DeviceFileSource(path));

        if (!mounted) return;
        setState(() => _isPlaying = true);
      }
    } catch (error) {
      if (!mounted) return;

      setState(() => _isPlaying = false);
      _showMessage('Could not play voice note: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.reminder.voiceNotePath;
    final hasRecording = path != null && File(path).existsSync();
    final isCompleted =
        widget.reminder.voiceNoteCompleted && hasRecording;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xffFFF9F8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffFFE7E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCompleted ? Icons.check_circle : Icons.mic,
                color: isCompleted ? Colors.green : const Color(0xffF25F5C),
                size: 25,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Voice Note',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isCompleted)
                const Text(
                  'Saved',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _isRecording
                ? 'Recording in progress...'
                : hasRecording
                    ? 'Your voice note is ready to play.'
                    : 'Record a personal voice message for this event.',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_isRecording)
                FilledButton.icon(
                  onPressed: _isBusy
                      ? null
                      : () async {
                          setState(() => _isBusy = true);
                          try {
                            await _stopRecording();
                          } finally {
                            if (mounted) {
                              setState(() => _isBusy = false);
                            }
                          }
                        },
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop & Save'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xffF25F5C),
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: _isBusy
                      ? null
                      : () async {
                          setState(() => _isBusy = true);
                          try {
                            await _startRecording();
                          } finally {
                            if (mounted) {
                              setState(() => _isBusy = false);
                            }
                          }
                        },
                  icon: const Icon(Icons.mic),
                  label: Text(hasRecording ? 'Re-record' : 'Record Voice'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xffF25F5C),
                  ),
                ),
              if (hasRecording && !_isRecording)
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : _togglePlayback,
                  icon: Icon(
                    _isPlaying ? Icons.stop : Icons.play_arrow,
                  ),
                  label: Text(_isPlaying ? 'Stop' : 'Play'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
