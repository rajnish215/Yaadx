import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'reminder_controller.dart';
import 'reminder_model.dart';


class AddReminderScreen extends StatefulWidget {
  const AddReminderScreen({super.key});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();

  String relation = "Friend";
  String eventType = "Birthday";



  @override
  void dispose() {
    nameController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  Future<void> pickTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );

    if (pickedTime != null) {
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
      prefixIcon: Icon(
        icon,
        color: const Color(0xffFF6B81),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
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
        borderSide: const BorderSide(
          color: Color(0xffFF6B81),
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<ReminderController>(
  context,
  listen: false,
);
    return Scaffold(
      backgroundColor: const Color(0xffFFF7F6),
     appBar: AppBar(
  backgroundColor: const Color(0xffFFF7F6),
  elevation: 0,
  centerTitle: true,
  iconTheme: const IconThemeData(
    color: Colors.black,
  ),
  title: const Text(
    "Add Reminder",
    style: TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
    ),
  ),
),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Person Name
              TextFormField(
                controller: nameController,
                decoration: inputDecoration(
                  hint: "Person Name",
                  icon: Icons.person_outline,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter person name";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Relation
              DropdownButtonFormField<String>(
                value: relation,
                isExpanded: true,
                decoration: inputDecoration(
                  hint: "Relation",
                  icon: Icons.favorite_outline,
                ),
                items: const [
                  DropdownMenuItem(value: "Friend", child: Text("Friend")),
                  DropdownMenuItem(value: "Mother", child: Text("Mother")),
                  DropdownMenuItem(value: "Father", child: Text("Father")),
                  DropdownMenuItem(value: "Brother", child: Text("Brother")),
                  DropdownMenuItem(value: "Sister", child: Text("Sister")),
                  DropdownMenuItem(value: "Family", child: Text("Family")),
                  DropdownMenuItem(value: "Colleague", child: Text("Colleague")),
                  DropdownMenuItem(value: "Other", child: Text("Other")),
                ],
                onChanged: (value) {
                  setState(() {
                    relation = value!;
                  });
                },
              ),

              const SizedBox(height: 20),

              // Event Type
              DropdownButtonFormField<String>(
                value: eventType,
                isExpanded: true,
                decoration: inputDecoration(
                  hint: "Event Type",
                  icon: Icons.celebration_outlined,
                ),
                items: const [
                  DropdownMenuItem(value: "Birthday", child: Text("Birthday")),
                  DropdownMenuItem(value: "Anniversary", child: Text("Anniversary")),
                  DropdownMenuItem(value: "Meeting", child: Text("Meeting")),
                  DropdownMenuItem(value: "Festival", child: Text("Festival")),
                  DropdownMenuItem(value: "Other", child: Text("Other")),
                ],
                onChanged: (value) {
                  setState(() {
                    eventType = value!;
                  });
                },
              ),

              const SizedBox(height: 20),

              // Date
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                leading: const Icon(
                  Icons.calendar_today,
                  color: Color(0xffFF6B81),
                ),
                title: const Text("Event Date"),
                subtitle: Text(
                  "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                onTap: pickDate,
              ),

              const SizedBox(height: 20),

              // Time
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                leading: const Icon(
                  Icons.access_time,
                  color: Color(0xffFF6B81),
                ),
                title: const Text("Reminder Time"),
                subtitle: Text(
                  selectedTime.format(context),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                onTap: pickTime,
              ),

              const SizedBox(height: 20),

              // Notes
              TextFormField(
                controller: noteController,
                maxLines: 4,
                decoration: inputDecoration(
                  hint: "Note (Optional)",
                  icon: Icons.notes,
                ),
              ),

              const SizedBox(height: 35),
              SizedBox(
  width: double.infinity,
  height: 55,
  child: ElevatedButton(
    onPressed: () async {

      if (!_formKey.currentState!.validate()) return;

      final reminder = ReminderModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: nameController.text.trim(),
        relation: relation,
        eventType: eventType,
        date: selectedDate,
        time: selectedTime.format(context),
        note: noteController.text.trim(),
        notificationEnabled: true,
        isCompleted: false,
        createdAt: DateTime.now(),
      );

      await controller.addReminder(reminder);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Reminder Added Successfully 🎉"),
        ),
      );

      Navigator.pop(context);
    },

    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xffFF6B81),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),

    child: const Text(
      "Save Reminder",
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