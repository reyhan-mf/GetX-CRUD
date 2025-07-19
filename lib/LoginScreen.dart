import 'package:crud_sqlite_provider/home.dart';
import 'package:crud_sqlite_provider/service/google_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LoginPage extends StatelessWidget {
  LoginPage({super.key});

  FirebaseService firebaseService = FirebaseService();
  User? user;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () async {
            try {
              user = await firebaseService.signInWithGoogle();
              if (user != null) {
                // User is signed in
                print("user signed in: $user");
                Get.to(() => HomePage());
              } else {
                // Sign-in failed
                print("Sign-in failed");
              }
            } catch (e) {
              print("Error during sign-in: $e");
            }
          },
          child: Text('Login'),
        ),
      ),
    );
  }
}
