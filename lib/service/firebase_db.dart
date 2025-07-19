import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';

class RealtimeDatabaseService extends GetxController {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Observable current user ID
  var currentUserId = Rxn<String>();

  @override
  void onInit() {
    super.onInit();
    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) {
      currentUserId.value = user?.uid;
      print('Auth state changed - User ID: ${currentUserId.value}');
    });
  }

  // Method untuk reset state ketika logout
  void resetState() {
    currentUserId.value = null;
    print('RealtimeDatabaseService state reset');
  }

  // Database reference untuk tasks
  DatabaseReference get tasksRef {
    final userId = currentUserId.value ?? _auth.currentUser?.uid ?? '';
    print('Getting tasksRef for user: $userId'); // Output: "hv2AwaIH0jUO49cDlWlWgex2Bzo1"
    return _database.ref().child('tasks').child(userId); // ✅ Path: tasks/hv2AwaIH0jUO49cDlWlWgex2Bzo1/
  }

  // CREATE - Tambah task baru
  Future<String?> addTask(Map<String, dynamic> taskData) async {
    try {
      if (currentUserId.value == null) return null;

      taskData['userId'] = currentUserId.value;
      taskData['createdAt'] = ServerValue.timestamp;

      DatabaseReference newTaskRef = tasksRef.push();
      await newTaskRef.set(taskData);
      return newTaskRef.key;
    } catch (e) {
      print('Error adding task: $e');
      return null;
    }
  }

  // READ - Get semua tasks (Stream untuk real-time updates)
  Stream<DatabaseEvent> getTasks() {
    if (currentUserId.value == null) {
      return const Stream.empty();
    }
    return tasksRef.orderByChild('createdAt').onValue;
  }

  // READ - Get task by ID
  Future<DataSnapshot?> getTaskById(String taskId) async {
    try {
      if (currentUserId.value == null) return null;
      DataSnapshot snapshot = await tasksRef.child(taskId).get();
      return snapshot;
    } catch (e) {
      print('Error getting task: $e');
      return null;
    }
  }

  // UPDATE - Update task
  Future<bool> updateTask(String taskId, Map<String, dynamic> taskData) async {
    try {
      if (currentUserId.value == null) return false;

      taskData['updatedAt'] = ServerValue.timestamp;
      await tasksRef.child(taskId).update(taskData);
      return true;
    } catch (e) {
      print('Error updating task: $e');
      return false;
    }
  }

  // DELETE - Hapus task
  Future<bool> deleteTask(String taskId) async {
    try {
      if (currentUserId.value == null) return false;
      await tasksRef.child(taskId).remove();
      return true;
    } catch (e) {
      print('Error deleting task: $e');
      return false;
    }
  }

  // DELETE - Hapus semua tasks
  Future<bool> deleteAllTasks() async {
    try {
      if (currentUserId.value == null) return false;
      await tasksRef.remove();
      return true;
    } catch (e) {
      print('Error deleting all tasks: $e');
      return false;
    }
  }

  // Batch update (untuk multiple tasks)
  Future<bool> batchUpdate(Map<String, Map<String, dynamic>> updates) async {
    try {
      if (currentUserId.value == null) return false;

      Map<String, dynamic> updateMap = {};
      updates.forEach((taskId, taskData) {
        taskData['updatedAt'] = ServerValue.timestamp;
        updateMap['tasks/${currentUserId.value}/$taskId'] = taskData;
      });

      await _database.ref().update(updateMap);
      return true;
    } catch (e) {
      print('Error batch updating: $e');
      return false;
    }
  }
}
