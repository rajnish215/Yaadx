import 'reminder_validation.dart';
import 'dart:io';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'reminder_controller.dart';
import 'reminder_model.dart';

class AddReminderScreen extends StatefulWidget {
  const AddReminderScreen({super.key, this.selectedDate, this.reminder});

  final DateTime? selectedDate;
  final ReminderModel? reminder;

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  final TextEditingController captionController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _selectedPhotos = [];

  late DateTime selectedDate;
  TimeOfDay selectedTime = TimeOfDay.now();

  String relation = 'Friend';
  String eventType = 'Birthday';

  bool repeatYearly = true;
  int advanceDays = 10;
  bool voiceAlert = false;
  bool _isSaving = false;
  bool _isPickingPhotos = false;

  static const Color _accent = Color(0xffFF6B81);

  @override
  void initState() {
    super.initState();

    final existing = widget.reminder;
    if (existing != null) {
      nameController.text = existing.name;
      phoneController.text = existing.phoneNumber ?? '';
      noteController.text = existing.note;
      captionController.text = existing.memoryCaption;
      relation = existing.relation;
      eventType = existing.eventType;
      selectedTime = TimeOfDay.fromDateTime(existing.eventDateTime);
      repeatYearly = existing.repeatYearly;
      advanceDays = existing.advanceDays;
      voiceAlert = existing.voiceAlert;
      _selectedPhotos.addAll(
        existing.memoryPhotoPaths.map((path) => XFile(path)),
      );
    }
    final date = existing?.date ?? widget.selectedDate ?? DateTime.now();

    selectedDate = DateTime(date.year, date.month, date.day);
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    noteController.dispose();
    captionController.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate.isBefore(today) ? today : selectedDate,
      firstDate: today,
      lastDate: DateTime(2100),
    );

    if (pickedDate != null && mounted) {
      setState(() {
        selectedDate = DateUtils.dateOnly(pickedDate);
      });
    }
  }

  Future<void> pickTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );

    if (pickedTime != null && mounted) {
      setState(() {
        selectedTime = pickedTime;
      });
    }
  }

  InputDecoration inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: _accent),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
    );
  }

  Future<void> pickPhotos() async {
    if (_isPickingPhotos) return;

    setState(() => _isPickingPhotos = true);

    try {
      final photos = await _imagePicker.pickMultiImage(imageQuality: 90);

      if (!mounted || photos.isEmpty) return;

      final additions = photos
          .where(
            (photo) => !_selectedPhotos.any((item) => item.path == photo.path),
          )
          .toList();
      if (_selectedPhotos.length + additions.length >
          ReminderValidation.maxPhotos) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Choose up to 10 photos per event. Remove a photo before adding more.',
            ),
          ),
        );
        return;
      }
      setState(() {
        for (final photo in additions) {
          if (!_selectedPhotos.any((item) => item.path == photo.path)) {
            _selectedPhotos.add(photo);
          }
        }
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not select photos. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingPhotos = false);
      }
    }
  }

  void removePhoto(int index) {
    setState(() => _selectedPhotos.removeAt(index));
  }

  Future<List<String>> _copyPhotosToAppStorage() async {
    if (_selectedPhotos.isEmpty) return [];

    final directory = await getApplicationDocumentsDirectory();

    final memoryDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}yaadx_memories',
    );

    if (!await memoryDirectory.exists()) {
      await memoryDirectory.create(recursive: true);
    }

    final savedPaths = <String>[];

    for (var i = 0; i < _selectedPhotos.length; i++) {
      final photo = _selectedPhotos[i];
      if (widget.reminder?.memoryPhotoPaths.contains(photo.path) ?? false) {
        savedPaths.add(photo.path);
        continue;
      }
      final originalName = photo.name;
      final dotIndex = originalName.lastIndexOf('.');

      final extension = dotIndex >= 0
          ? originalName.substring(dotIndex)
          : '.jpg';

      final uniqueName =
          'memory_${DateTime.now().microsecondsSinceEpoch}_$i$extension';

      final destination = File(
        '${memoryDirectory.path}${Platform.pathSeparator}$uniqueName',
      );

      await File(photo.path).copy(destination.path);
      savedPaths.add(destination.path);
    }

    return savedPaths;
  }

  Future<void> saveReminder() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    if (_selectedPhotos.length > ReminderValidation.maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose up to 10 photos per event.')),
      );
      return;
    }
    final chosen = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    if (!repeatYearly && !chosen.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choose a future date and time, or enable yearly repeat.',
          ),
        ),
      );
      return;
    }
    setState(() => _isSaving = true);

    try {
      final controller = context.read<ReminderController>();

      final phoneInput = phoneController.text.trim();

      final phone = phoneInput.isEmpty
          ? null
          : phoneInput.replaceAll(RegExp(r'\D'), '');

      final savedPhotoPaths = await _copyPhotosToAppStorage();

      if (!mounted) return;

      final reminder = ReminderModel(
        id:
            widget.reminder?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: nameController.text.trim(),
        relation: relation,
        phoneNumber: phone,
        eventType: eventType,
        date: selectedDate,
        time:
            '${selectedTime.hour.toString().padLeft(2, '0')}:'
            '${selectedTime.minute.toString().padLeft(2, '0')}',
        note: noteController.text.trim(),
        memoryPhotoPaths: savedPhotoPaths,
        memoryCaption: captionController.text.trim(),
        repeatYearly: repeatYearly,
        advanceDays: advanceDays,
        voiceAlert: voiceAlert,
        voiceNotePath: widget.reminder?.voiceNotePath,
        voiceNoteCompleted: widget.reminder?.voiceNoteCompleted ?? false,
        messageSent: widget.reminder?.messageSent ?? false,
        notificationEnabled: widget.reminder?.notificationEnabled ?? true,
        isCompleted: widget.reminder?.isCompleted ?? false,
        createdAt: widget.reminder?.createdAt ?? DateTime.now(),
      );

      if (widget.reminder == null) {
        await controller.addReminder(reminder);
      } else {
        await controller.updateReminder(reminder);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reminder and memories saved successfully 🎉'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is FormatException
                ? e.message
                : e is PlatformException
                ? e.message ?? 'Could not save alert.'
                : 'Could not save reminder. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildMemorySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.photo_library_outlined, color: _accent),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Photo Memories',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Save special photos with this reminder.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isPickingPhotos ? null : pickPhotos,
              icon: _isPickingPhotos
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _isPickingPhotos ? 'Opening gallery...' : 'Choose Photos',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent,
                side: const BorderSide(color: _accent),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (_selectedPhotos.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              '${_selectedPhotos.length} photo(s) selected',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedPhotos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final photo = _selectedPhotos[index];

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(photo.path),
                          width: 105,
                          height: 105,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 105,
                            height: 105,
                            color: Colors.black12,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -5,
                        right: -5,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => removePhoto(index),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: captionController,
            maxLength: ReminderValidation.maxText,
            validator: (v) => ReminderValidation.textError(
              v ?? '',
              ReminderValidation.maxText,
              'Caption',
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            decoration: inputDecoration(
              hint: 'Memory caption or WhatsApp message (Optional)',
              icon: Icons.chat_bubble_outline,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You can use this caption when sharing the photos later.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffFFF7F6),
      appBar: AppBar(
        backgroundColor: const Color(0xffFFF7F6),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          widget.reminder == null ? 'Add Reminder' : 'Edit Reminder',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameController,
                maxLength: ReminderValidation.maxName,
                textCapitalization: TextCapitalization.words,
                decoration: inputDecoration(
                  hint: 'Person Name',
                  icon: Icons.person_outline,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter person name';
                  }
                  return ReminderValidation.textError(
                    value,
                    ReminderValidation.maxName,
                    'Name',
                  );
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration:
                    inputDecoration(
                      hint: 'WhatsApp Number (Optional)',
                      icon: Icons.phone_outlined,
                    ).copyWith(
                      helperText: 'Include country code, e.g. 919876543210',
                    ),
                validator: (value) {
                  final input = value?.trim() ?? '';
                  if (input.isEmpty) return null;

                  final digits = input.replaceAll(RegExp(r'\D'), '');

                  if (!RegExp(r'^\d{8,15}$').hasMatch(digits)) {
                    return 'Enter a valid number with country code';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: relation,
                isExpanded: true,
                decoration: inputDecoration(
                  hint: 'Relation',
                  icon: Icons.favorite_outline,
                ),
                items: const [
                  DropdownMenuItem(value: 'Friend', child: Text('Friend')),
                  DropdownMenuItem(value: 'Mother', child: Text('Mother')),
                  DropdownMenuItem(value: 'Father', child: Text('Father')),
                  DropdownMenuItem(value: 'Brother', child: Text('Brother')),
                  DropdownMenuItem(value: 'Sister', child: Text('Sister')),
                  DropdownMenuItem(value: 'Family', child: Text('Family')),
                  DropdownMenuItem(
                    value: 'Colleague',
                    child: Text('Colleague'),
                  ),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => relation = value);
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: eventType,
                isExpanded: true,
                decoration: inputDecoration(
                  hint: 'Event Type',
                  icon: Icons.celebration_outlined,
                ),
                items: const [
                  DropdownMenuItem(value: 'Birthday', child: Text('Birthday')),
                  DropdownMenuItem(
                    value: 'Anniversary',
                    child: Text('Anniversary'),
                  ),
                  DropdownMenuItem(value: 'Meeting', child: Text('Meeting')),
                  DropdownMenuItem(value: 'Festival', child: Text('Festival')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => eventType = value);
                },
              ),
              const SizedBox(height: 20),
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                leading: const Icon(Icons.calendar_today, color: _accent),
                title: const Text('Event Date'),
                subtitle: Text(
                  '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                onTap: pickDate,
              ),
              const SizedBox(height: 20),
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                leading: const Icon(Icons.access_time, color: _accent),
                title: const Text('Reminder Time'),
                subtitle: Text(selectedTime.format(context)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                onTap: pickTime,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: noteController,
                maxLength: ReminderValidation.maxText,
                validator: (v) => ReminderValidation.textError(
                  v ?? '',
                  ReminderValidation.maxText,
                  'Note',
                ),
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: inputDecoration(
                  hint: 'Note (Optional)',
                  icon: Icons.notes,
                ),
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Repeat every year'),
                subtitle: const Text(
                  'February 29 repeats on February 28 in non-leap years.',
                ),
                value: repeatYearly,
                onChanged: (value) => setState(() => repeatYearly = value),
              ),
              DropdownButtonFormField<int>(
                initialValue: advanceDays,
                decoration: const InputDecoration(
                  labelText: 'Advance reminders',
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Event day only')),
                  DropdownMenuItem(
                    value: 1,
                    child: Text('1 day before + event day'),
                  ),
                  DropdownMenuItem(
                    value: 3,
                    child: Text('Daily from 3 days before'),
                  ),
                  DropdownMenuItem(
                    value: 7,
                    child: Text('Daily from 7 days before'),
                  ),
                  DropdownMenuItem(
                    value: 10,
                    child: Text('Daily from 10 days before'),
                  ),
                ],
                onChanged: (value) => setState(() => advanceDays = value ?? 10),
              ),
              SwitchListTile(
                title: const Text('Spoken alert one day before'),
                subtitle: const Text(
                  'Adds a spoken reminder one day before, at the saved time: “Tomorrow is Ankit’s birthday.” Event day has a normal notification only. Phone sound and Do Not Disturb settings still apply.',
                ),
                value: voiceAlert,
                onChanged: (value) => setState(() => voiceAlert = value),
              ),
              const SizedBox(height: 20),
              _buildMemorySection(),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : saveReminder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    disabledBackgroundColor: _accent.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Reminder',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
