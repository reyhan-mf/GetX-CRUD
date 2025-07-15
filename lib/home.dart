import 'package:crud_sqlite_provider/controller/task_controller.dart';
import 'package:crud_sqlite_provider/inputPage.dart';
import 'package:crud_sqlite_provider/model/task_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  final TaskController taskController = Get.put(TaskController());

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
                        context, Get.find<TaskController>(), task),
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
      BuildContext context, TaskController controller, TaskModel task) {
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
              controller.deleteTask(task.id);
              Get.back();
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
