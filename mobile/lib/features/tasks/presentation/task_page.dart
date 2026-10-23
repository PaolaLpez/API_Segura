import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'task_controller.dart';
import 'task_list_view.dart';

class TaskPage extends ConsumerWidget {
  const TaskPage({super.key});

  void _showAddTaskDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                ref.read(taskControllerProvider.notifier).addTask(
                      title,
                      descController.text.trim().isEmpty ? null : descController.text.trim(),
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskState = ref.watch(taskControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Task Manager'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider).logout();
              ref.read(authStateProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: TaskListView(
        loading: taskState.loading,
        tasks: taskState.tasks,
        errorMessage: taskState.errorMessage,
        onRetry: () => ref.read(taskControllerProvider.notifier).loadTasks(),
        onToggle: (task) => ref.read(taskControllerProvider.notifier).toggleCompleted(task),
        onDelete: (task) => ref.read(taskControllerProvider.notifier).deleteTask(task),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(context, ref),
        tooltip: 'Add Task',
        child: const Icon(Icons.add),
      ),
    );
  }
}
