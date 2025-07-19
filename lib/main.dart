import 'package:crud_sqlite_provider/LoginScreen.dart';
import 'package:crud_sqlite_provider/controller/user_controller.dart';
import 'package:crud_sqlite_provider/home.dart';
import 'package:crud_sqlite_provider/service/firebase_db.dart';
import 'package:crud_sqlite_provider/service/google_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with proper configuration options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseDatabase.instance.setPersistenceEnabled(true);

  Get.put(FirebaseService());
  Get.put(RealtimeDatabaseService()); // Tambahkan ini
  // TaskRealtimeController akan diinisialisasi di HomePage untuk memastikan dependency injection yang benar
  Get.put(UserController(
      Get.find<FirebaseService>())); // Register UserController with GetX

  runApp(GetMaterialApp(
    title: 'Flutter Demo',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      useMaterial3: true,
    ),
    home: FirebaseAuth.instance.currentUser == null
        ? LoginPage() // Show login page if user is not authenticated
        : HomePage(), // Show home page if user is authenticated
  ));
}

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Demo',
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
//         useMaterial3: true,
//       ),
//       home: const HomePage(),
//     );
//   }
// }
