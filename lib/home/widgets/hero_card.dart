import 'package:flutter/material.dart';

class HeroCard extends StatelessWidget {
  const HeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // FIX: Padding kam kar di
      padding: const EdgeInsets.all(16), 
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [
            Color(0xffC8453A),
            Color(0xff8B231C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(.25),
            blurRadius: 20,
            offset: const Offset(0, 12),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Top Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12, // Thoda compact kiya
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 14, // Size reduced
                    ),
                    SizedBox(width: 5),
                    Text(
                      "NEXT EVENT",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12, // Font thoda chota
                        letterSpacing: 1,
                      ),
                    )
                  ],
                ),
              ),
              Container(
                height: 36, // Size reduced
                width: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),

          // FIX: Spacing reduce ki
          const SizedBox(height: 16), 

          /// Birthday + Cake
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pritam's Birthday",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26, // Font chota kiya
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8), // Spacing reduce ki
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color: Colors.white70,
                          size: 16, // Size reduced
                        ),
                        SizedBox(width: 6),
                        Text(
                          "Sat, 20 June 2026",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14, // Font chota kiya
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "🎂",
                style: TextStyle(fontSize: 65), // Emoji ka size chota kiya
              ),
            ],
          ),

          // FIX: Spacing reduce ki
          const SizedBox(height: 16), 


          // FIX: Spacing reduce ki
          const SizedBox(height: 10), 

          /// Countdown
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CountdownCircle(
                value: "03",
                label: "Days",
              ),
              CountdownCircle(
                value: "14",
                label: "Hours",
              ),
              CountdownCircle(
                value: "42",
                label: "Mins",
              ),
              CountdownCircle(
                value: "28",
                label: "Secs",
              ),
            ],
          ),

          // FIX: Spacing reduce ki
          const SizedBox(height: 20), 

          /// Button
          SizedBox(
            width: double.infinity,
            height: 50, // Button ki height kam ki
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffB35B52),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16), // Border radius update
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "🎉",
                    style: TextStyle(fontSize: 18), // Size reduced
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Celebrate Now",
                    style: TextStyle(
                      fontSize: 16, // Font chota kiya
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16, // Size reduced
                    color: Colors.white,
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class CountdownCircle extends StatelessWidget {
  final String value;
  final String label;

  const CountdownCircle({
    super.key,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 52, // Circle ki height kam ki
          width: 52,  // Circle ki width kam ki
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white24,
              width: 2.5,
            ),
          ),
          child: Center(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18, // Font chota kiya
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6), // Spacing reduce ki
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12, // Label font chota kiya
          ),
        )
      ],
    );
  }
}