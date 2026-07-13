import 'package:flutter/material.dart';
import 'widgets/header.dart';
import 'widgets/hero_card.dart';
import 'widgets/ai_suggestion_card.dart';
import 'widgets/quick_actions.dart';
import 'widgets/task_section.dart';
import 'widgets/upcoming_events.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffFFF7F6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              /// Header
              Header(),
              SizedBox(height: 25),

              /// Hero Card
              HeroCard(),
              SizedBox(height: 20),

              /// AI Suggestion
              AiSuggestionCard(),
              SizedBox(height: 25),

              /// Quick Actions
              QuickActions(),
              SizedBox(height: 25),

              /// Today's Tasks
              TaskSection(),
              SizedBox(height: 25),

              /// Upcoming Events
              UpcomingEvents(),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}