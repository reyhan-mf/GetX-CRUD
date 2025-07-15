import 'package:crud_sqlite_provider/model/task_model.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class TaskController extends GetxController {
  var tasks = <TaskModel>[].obs;
  var isLoading = false.obs;
  Database? _database;

  @override
  void onInit() {
    super.onInit();
    _initDatabase();
  }

  // Initialize database
  Future<void> _initDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'tasks.db');

      _database = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE tasks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              description TEXT,
              dateTime TEXT NOT NULL,
              createTime TEXT NOT NULL,
              isCompleted INTEGER NOT NULL DEFAULT 0
            )
            ''');
        },
      );

      loadTasks(); // Load existing tasks after database is ready
    } catch (e) {
      Get.snackbar('Database Error', 'Failed to initialize database: $e');
    }
  }

  // CREATE - Add new task
  Future<void> addTask(TaskModel task) async {
    try {
      isLoading.value = true;

      var taskMap = task.toJSON();
      taskMap.remove('id'); // Remove id for auto-increment

      final id = await _database!.insert('tasks', taskMap);

      final newTask = TaskModel(
        id: id,
        title: task.title,
        description: task.description,
        dateTime: task.dateTime,
        createTime: task.createTime,
        isCompleted: task.isCompleted,
      );

      tasks.add(newTask);
      Get.snackbar('Success', 'Task added successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to add task: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // READ - Load all tasks
  Future<void> loadTasks() async {
    try {
      isLoading.value = true;

      final List<Map<String, dynamic>> maps = await _database!.query('tasks');

      final taskList = List.generate(maps.length, (i) {
        return TaskModel.fromJSON(maps[i]);
      });

      tasks.value = taskList;
    } catch (e) {
      Get.snackbar('Error', 'Failed to load tasks: $e');
      print('Error loading tasks: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // UPDATE - Update existing task
  Future<void> updateTask(TaskModel task) async {
    try {
      isLoading.value = true;

      await _database!.update(
        'tasks',
        task.toJSON(),
        where: 'id = ?',
        whereArgs: [task.id],
      );

      var index = tasks.indexWhere((t) => t.id == task.id);
      if (index >= 0) {
        tasks[index] = task;
      }

      Get.snackbar('Success', 'Task updated successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to update task: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // DELETE - Delete task
  Future<void> deleteTask(int id) async {
    try {
      isLoading.value = true;

      await _database!.delete(
        'tasks',
        where: 'id = ?',
        whereArgs: [id],
      );

      tasks.removeWhere((task) => task.id == id);
      Get.snackbar('Success', 'Task deleted successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete task: $e');
    } finally {
      isLoading.value = false;
    }
  }
}
