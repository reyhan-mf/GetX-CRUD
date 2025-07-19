import 'package:crud_sqlite_provider/LoginScreen.dart';
// import 'package:crud_sqlite_provider/controller/task_controller.dart';
import 'package:crud_sqlite_provider/controller/task_firebase_controller.dart';
import 'package:crud_sqlite_provider/inputPage.dart';
import 'package:crud_sqlite_provider/model/task_model.dart';
import 'package:crud_sqlite_provider/service/firebase_db.dart';
import 'package:crud_sqlite_provider/service/google_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});
  final TaskRealtimeController taskController =
      Get.put(TaskRealtimeController()); // Inisialisasi di sini
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('To Do List'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              taskController.loadTasks(); // Refresh task list
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(user?.displayName ?? 'User'),
              accountEmail: Text(user?.email ?? 'No email'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  user?.displayName?.substring(0, 1) ?? 'U',
                  style: TextStyle(fontSize: 24.0),
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () async {
                // Reset RealtimeDatabaseService state
                final dbService = Get.find<RealtimeDatabaseService>();
                dbService.resetState();

                // Reset TaskController
                if (Get.isRegistered<TaskRealtimeController>()) {
                  Get.delete<TaskRealtimeController>();
                }

                final result = await Get.find<FirebaseService>().signOut();
                if (result == true) {
                  Get.offAll(LoginPage());
                }
              },
            ),
          ],
        ),
      ),
      body: Obx(() {
        if (taskController.isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }

        if (taskController.tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.task_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No tasks yet!',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap + to add your first task',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: taskController.tasks.length,
          itemBuilder: (context, index) {
            final task = taskController.tasks[index];
            return DataCard(task: task);
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Action to add a new item
          Get.to(InputPage());
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class DataCard extends StatelessWidget {
  final TaskModel task;

  const DataCard({
    super.key,
    required this.task,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
          color: _getDueDateColor(task.dateTime),
          border: Border.all(color: Colors.black, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 12.0),
        margin: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      task.description.isEmpty
                          ? 'No description'
                          : task.description,
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Due Date: ${task.dateTime.day}/${task.dateTime.month}/${task.dateTime.year}',
                      style: TextStyle(fontSize: 11),
                    )
                  ]),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Get.to(InputPage(task: task)),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.edit, size: 32, color: Colors.black),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showDeleteDialog(
                        context, Get.find<TaskRealtimeController>(), task),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.delete, size: 32, color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ));
  }

  Color _getDueDateColor(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (due.isBefore(today)) {
      return Colors.red; // Overdue
    } else if (due.isAtSameMomentAs(today)) {
      return Colors.orange; // Due today
    } else {
      return Colors.grey; // Future
    }
  }

  void _showDeleteDialog(
      BuildContext context, TaskRealtimeController controller, TaskModel task) {
    Get.dialog(
      AlertDialog(
        title: Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (task.id != null) {
                controller.deleteTask(task.id!);
              } else {
                // Handle the case where task.id is null, e.g., show an error message
                Get.snackbar('Error', 'Task ID is null');
              }
              Get.back();
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
