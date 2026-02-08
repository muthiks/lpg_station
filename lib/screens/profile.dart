import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.all(5),
        child: Column(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 15, 0, 20),
                child: const Text(
                  'YOUR PROFILE',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            //profile picture
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                ),
                padding: EdgeInsets.all(10),
                child: Column(
                  children: [
                    const Icon(
                      Icons.person_2_sharp,
                      size: 80,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }
}
