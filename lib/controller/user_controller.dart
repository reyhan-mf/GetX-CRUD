import 'package:crud_sqlite_provider/service/google_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserController {
  final FirebaseService firebaseService;

  UserController(this.firebaseService);

// Get user name
  String getUserName() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.displayName ?? 'User';
  }
// Get user email
  String getUserEmail() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.email ?? 'No email';
  }

  
}