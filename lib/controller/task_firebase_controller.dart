import 'dart:async';
import 'package:crud_sqlite_provider/model/task_model.dart';
import 'package:crud_sqlite_provider/service/firebase_db.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';

class TaskRealtimeController extends GetxController {
  final RealtimeDatabaseService _realtimeService =
      Get.find<RealtimeDatabaseService>();

  var tasks = <TaskModel>[].obs;
  var isLoading = false.obs;
  StreamSubscription<DatabaseEvent>? _tasksSubscription;

  @override
  void onInit() {
    super.onInit();

    // Listen to user ID changes and reload tasks
    ever(_realtimeService.currentUserId, (String? userId) {
      print('User changed in TaskController: $userId');
      _cancelPreviousSubscription();
      if (userId != null) {
        loadTasks();
      } else {
        tasks.clear();
      }
    });

    // Initial load if user already exists
    if (_realtimeService.currentUserId.value != null) {
      loadTasks();
    }
  }

  @override
  void onClose() {
    _cancelPreviousSubscription();
    super.onClose();
  }

  void _cancelPreviousSubscription() {
    _tasksSubscription?.cancel();
    _tasksSubscription = null;
  }

  // Load tasks dari Realtime Database
  void loadTasks() {
    if (_realtimeService.currentUserId.value == null) {
      tasks.clear();
      return;
    }

    isLoading.value = true;
    _cancelPreviousSubscription();

    _tasksSubscription = _realtimeService.getTasks().listen(
      (DatabaseEvent event) {
        print(
            'Received data for user: ${_realtimeService.currentUserId.value}');
        if (event.snapshot.value != null) {
          Map<dynamic, dynamic> tasksMap =
              event.snapshot.value as Map<dynamic, dynamic>;

          List<TaskModel> taskList = [];
          tasksMap.forEach((key, value) {
            if (value is Map<dynamic, dynamic>) {
              taskList.add(TaskModel.fromRealtimeDatabase(key, value));
            }
          });

          // Sort by createdAt (newest first)
          taskList
              .sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));

          tasks.value = taskList;
        } else {
          tasks.value = [];
        }
        isLoading.value = false;
      },
      onError: (error) {
        print('Error loading tasks: $error');
        isLoading.value = false;
        Get.snackbar('Error', 'Failed to load tasks');
      },
    );
  }

  // Add task
  Future<void> addTask(TaskModel task) async {
    isLoading.value = true;

    String? taskId = await _realtimeService.addTask(task.toRealtimeDatabase());

    if (taskId != null) {
      Get.snackbar('Success', 'Task added successfully');
      Get.back(); // Kembali ke halaman sebelumnya
    } else {
      Get.snackbar('Error', 'Failed to add task');
    }

    isLoading.value = false;
  }

  // Update task
  Future<void> updateTask(TaskModel task) async {
    if (task.id == null) return;

    isLoading.value = true;

    bool success = await _realtimeService.updateTask(
      task.id!,
      task.toRealtimeDatabase(),
    );

    if (success) {
      Get.snackbar('Success', 'Task updated successfully');
      Get.back();
    } else {
      Get.snackbar('Error', 'Failed to update task');
    }

    isLoading.value = false;
  }

  // Delete task
  Future<void> deleteTask(String taskId) async {
    bool success = await _realtimeService.deleteTask(taskId);

    if (success) {
      Get.snackbar('Success', 'Task deleted successfully');
    } else {
      Get.snackbar('Error', 'Failed to delete task');
    }
  }

  // Delete all tasks
  Future<void> deleteAllTasks() async {
    bool success = await _realtimeService.deleteAllTasks();

    if (success) {
      Get.snackbar('Success', 'All tasks deleted successfully');
    } else {
      Get.snackbar('Error', 'Failed to delete all tasks');
    }
  }

  // Refresh tasks manually
  void refreshTasks() {
    loadTasks();
  }
}
