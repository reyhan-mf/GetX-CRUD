import 'package:crud_sqlite_provider/controller/task_controller.dart';
import 'package:crud_sqlite_provider/model/task_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class InputPage extends StatefulWidget {
  final TaskModel? task;
  const InputPage({super.key, this.task});

  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _dueDate;

  final TaskController taskController = Get.find<TaskController>();

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      _dueDate = widget.task!.dateTime;
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  void _saveTask() {
    if (_titleController.text.isEmpty) {
      Get.snackbar('Error', 'Title cannot be empty');
      return;
    }

    final task = TaskModel(
      id: widget.task?.id ?? 0,
      title: _titleController.text,
      description: _descriptionController.text,
      dateTime: _dueDate ?? DateTime.now(),
      createTime: DateTime.now(),
    );

    if (widget.task == null) {
      taskController.addTask(task);
    } else {
      taskController.updateTask(task);
    }

    Get.back();
  }

  @override
  Widget build(context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Task'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: 'Task Title'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Task Description'),
            ),
            TextField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: () {
                  if (_dueDate == null) {
                    return 'Select due date';
                  } else {
                    return 'Due Date: ${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}';
                  }
                }(),
                hintText: () {
                  if (_dueDate == null) {
                    return 'Select due date';
                  } else {
                    return '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}';
                  }
                }(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: _selectDate,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _saveTask();
              },
              child: Text('Save Task'),
            ),
          ],
        ),
      ),
    );
  }
}
