import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../reminder/reminder_controller.dart';
import '../reminder/reminder_model.dart';
import '../reminder/widgets/reminder_tile.dart';

import 'widgets/search_bar.dart';
import 'widgets/empty_search.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController searchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReminderController>().loadReminders();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReminderController>(
      builder: (context, controller, child) {

        final query =
            searchController.text.toLowerCase();

        final List<ReminderModel> filteredList =
            controller.reminders.where((reminder) {

          return reminder.name
                  .toLowerCase()
                  .contains(query) ||

              reminder.relation
                  .toLowerCase()
                  .contains(query) ||

              reminder.eventType
                  .toLowerCase()
                  .contains(query);
        }).toList();

        return Scaffold(
          backgroundColor: const Color(0xffFFF7F6),

          appBar: AppBar(
            backgroundColor: const Color(0xffFFF7F6),
            elevation: 0,
            centerTitle: true,
            iconTheme:
                const IconThemeData(color: Colors.black),

            title: const Text(
              "Search",
              style: TextStyle(
                color: Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          body: Padding(
            padding: const EdgeInsets.all(20),

            child: Column(
              children: [

                SearchBarWidget(
                  controller: searchController,
                  onChanged: (value) {
                    setState(() {});
                  },
                ),

                const SizedBox(height: 20),

                Expanded(

                  child: filteredList.isEmpty

                      ? const EmptySearch()

                      : ListView.builder(

                          itemCount:
                              filteredList.length,

                          itemBuilder:
                              (context, index) {

                            final reminder =
                                filteredList[index];

                            return ReminderTile(

                              reminder: reminder,

                              onDelete: () async {

                                await controller
                                    .deleteReminder(
                                  reminder.id,
                                );
                              },

                              onNotificationToggle:
                                  () async {

                                await controller
                                    .toggleNotification(
                                  reminder.id,
                                );
                              },

                              onTap: () {
                                // Future:
                                // Open Reminder Details
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}