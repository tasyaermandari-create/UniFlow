import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_theme.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final FirestoreService firestoreService = FirestoreService();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  String selectedPriority = 'Medium';
  DateTime selectedDeadline = DateTime.now().add(const Duration(days: 1));
  TimeOfDay selectedDeadlineTime = const TimeOfDay(hour: 23, minute: 59);

  bool isSaving = false;

  static const Color pageColor = Color(0xFFF4F7FD);
  static const Color navy = Color(0xFF173B70);
  static const Color blue = Color(0xFF2874D0);
  static const Color paleBlue = Color(0xFFEAF2FF);

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  int notificationId(String documentId) {
    var hash = 0x811C9DC5;

    for (final unit in documentId.codeUnits) {
      hash = (hash ^ unit) * 0x01000193;
      hash &= 0x7FFFFFFF;
    }

    return hash == 0 ? 1 : hash;
  }

  DateTime combineDeadline(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> updateTaskReminder({
    required String taskId,
    required String title,
    required DateTime deadline,
    required bool completed,
  }) async {
    final id = notificationId(taskId);

    await NotificationService.instance.cancelNotification(id);

    if (completed) return;

    final reminderTime = deadline.subtract(const Duration(hours: 1));

    if (!reminderTime.isAfter(DateTime.now())) return;

    final permissionGranted = await NotificationService.instance
        .requestPermission();

    if (!permissionGranted) return;

    await NotificationService.instance.scheduleTaskReminder(
      taskId: id,
      taskTitle: title,
      deadline: deadline,
    );
  }

  Future<void> showTaskDialog({
    String? taskId,
    Map<String, dynamic>? task,
  }) async {
    final isEdit = taskId != null;

    titleController.text = task?['title'] ?? '';
    descriptionController.text = task?['description'] ?? '';
    selectedPriority = task?['priority'] ?? 'Medium';

    final deadlineValue = task?['deadline'];

    if (deadlineValue is Timestamp) {
      final savedDeadline = deadlineValue.toDate();
      selectedDeadline = savedDeadline;
      selectedDeadlineTime = TimeOfDay(
        hour: savedDeadline.hour,
        minute: savedDeadline.minute,
      );
    } else {
      selectedDeadline = DateTime.now().add(const Duration(days: 1));
      selectedDeadlineTime = const TimeOfDay(hour: 23, minute: 59);
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: paleBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.task_alt_rounded, color: blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit Task' : 'Create New Task',
                      style: const TextStyle(
                        color: navy,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Task Title',
                        prefixIcon: const Icon(Icons.edit_note_rounded),
                        filled: true,
                        fillColor: pageColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        prefixIcon: const Icon(Icons.description_outlined),
                        filled: true,
                        fillColor: pageColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPriority,
                      decoration: InputDecoration(
                        labelText: 'Priority',
                        prefixIcon: const Icon(Icons.flag_outlined),
                        filled: true,
                        fillColor: pageColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: ['High', 'Medium', 'Low'].map((priority) {
                        return DropdownMenuItem(
                          value: priority,
                          child: Text(priority),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedPriority = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    _dialogOption(
                      icon: Icons.calendar_month_rounded,
                      title: 'Deadline Date',
                      value:
                          '${selectedDeadline.day}/${selectedDeadline.month}/${selectedDeadline.year}',
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedDeadline,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );

                        if (picked != null) {
                          setDialogState(() {
                            selectedDeadline = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    _dialogOption(
                      icon: Icons.access_time_rounded,
                      title: 'Deadline Time',
                      value: selectedDeadlineTime.format(dialogContext),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: dialogContext,
                          initialTime: selectedDeadlineTime,
                        );

                        if (picked != null) {
                          setDialogState(() {
                            selectedDeadlineTime = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: paleBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.notifications_active_outlined,
                            color: blue,
                            size: 19,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pengingat akan muncul 1 jam sebelum deadline.',
                              style: TextStyle(fontSize: 11, color: navy),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final title = titleController.text.trim();

                          if (title.isEmpty) {
                            showMessage('Task title tidak boleh kosong');
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                          });

                          try {
                            final deadline = combineDeadline(
                              selectedDeadline,
                              selectedDeadlineTime,
                            );

                            if (isEdit) {
                              await firestoreService.updateTask(
                                taskId: taskId,
                                title: title,
                                description: descriptionController.text.trim(),
                                priority: selectedPriority,
                                deadline: deadline,
                                completed: task?['completed'] == true,
                              );

                              await updateTaskReminder(
                                taskId: taskId,
                                title: title,
                                deadline: deadline,
                                completed: task?['completed'] == true,
                              );
                            } else {
                              final newTaskId = await firestoreService.addTask(
                                title: title,
                                description: descriptionController.text.trim(),
                                priority: selectedPriority,
                                deadline: deadline,
                              );

                              await updateTaskReminder(
                                taskId: newTaskId,
                                title: title,
                                deadline: deadline,
                                completed: false,
                              );
                            }

                            if (!mounted) return;

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }

                            final reminderTime = deadline.subtract(
                              const Duration(hours: 1),
                            );

                            if (reminderTime.isAfter(DateTime.now())) {
                              showMessage(
                                'Task berhasil disimpan. Pengingat dijadwalkan 1 jam sebelum deadline.',
                              );
                            } else {
                              showMessage(
                                'Task berhasil disimpan, tetapi waktu pengingat sudah lewat.',
                              );
                            }
                          } catch (e) {
                            showMessage('Gagal menyimpan task: $e');
                          } finally {
                            if (mounted) {
                              setState(() {
                                isSaving = false;
                              });
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isEdit ? 'Update Task' : 'Save Task'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _dialogOption({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: pageColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: AppTheme.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      color: navy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: blue),
          ],
        ),
      ),
    );
  }

  Future<void> deleteTask(String taskId) async {
    try {
      await firestoreService.deleteTask(taskId);

      await NotificationService.instance.cancelNotification(
        notificationId(taskId),
      );

      showMessage('Task berhasil dihapus');
    } catch (e) {
      showMessage('Gagal menghapus task: $e');
    }
  }

  Future<void> toggleTask(String taskId, bool completed) async {
    try {
      await firestoreService.toggleTask(taskId: taskId, completed: completed);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final taskSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .doc(taskId)
          .get();

      final task = taskSnapshot.data();
      if (task == null) return;

      final deadlineValue = task['deadline'];

      if (deadlineValue is Timestamp) {
        await updateTaskReminder(
          taskId: taskId,
          title: task['title'] ?? 'Tugas',
          deadline: deadlineValue.toDate(),
          completed: completed,
        );
      }
    } catch (e) {
      showMessage('Gagal mengubah status: $e');
    }
  }

  Color priorityColor(String priority) {
    switch (priority) {
      case 'High':
        return const Color(0xFF4385F5);
      case 'Medium':
        return const Color(0xFF75A9FF);
      default:
        return const Color(0xFF9BBDF5);
    }
  }

  void openTaskDetail(String taskId, Map<String, dynamic> task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailPage(
          task: task,
          priorityColor: priorityColor(task['priority'] ?? 'Medium'),
          onEdit: () {
            Navigator.pop(context);
            showTaskDialog(taskId: taskId, task: task);
          },
          onDelete: () {
            Navigator.pop(context);
            deleteTask(taskId);
          },
          onToggle: (value) {
            toggleTask(taskId, value);
          },
        ),
      ),
    );
  }

  Widget buildTaskCard(String taskId, Map<String, dynamic> task) {
    final title = task['title'] ?? 'Untitled Task';
    final description = task['description'] ?? '';
    final priority = task['priority'] ?? 'Medium';
    final completed = task['completed'] == true;

    final deadlineValue = task['deadline'];
    final deadline = deadlineValue is Timestamp ? deadlineValue.toDate() : null;

    final color = priorityColor(priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF173B70).withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: completed,
            activeColor: blue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            onChanged: (value) {
              toggleTask(taskId, value ?? false);
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => openTaskDetail(taskId, task),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: completed ? AppTheme.grey : navy,
                        decoration: completed
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.grey,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 11),
                    Wrap(
                      spacing: 8,
                      runSpacing: 7,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            priority,
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (deadline != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 12,
                                color: AppTheme.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${deadline.day}/${deadline.month}/${deadline.year}',
                                style: const TextStyle(
                                  color: AppTheme.grey,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(width: 7),
                              const Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: AppTheme.grey,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                TimeOfDay.fromDateTime(
                                  deadline,
                                ).format(context),
                                style: const TextStyle(
                                  color: AppTheme.grey,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppTheme.grey),
            onSelected: (value) {
              if (value == 'edit') {
                showTaskDialog(taskId: taskId, task: task);
              } else if (value == 'delete') {
                deleteTask(taskId);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, color: blue),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildProgressCard(int completed, int total) {
    final progress = total == 0 ? 0.0 : completed / total;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2874D0), Color(0xFF5799E8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: blue.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Task Progress',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$completed / $total completed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${(progress * 100).round()}% of your tasks completed. Keep going!',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: const BoxDecoration(
                color: paleBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.task_alt_rounded, size: 55, color: blue),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Tasks Yet',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: navy,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Tap Add Task to create your first task.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTaskDialog(),
        backgroundColor: blue,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Task',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 17),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Tasks',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: navy,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Organize your day and stay productive.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.grey.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.assignment_turned_in_rounded,
                      color: blue,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: firestoreService.getTasks(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Gagal memuat tugas:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: blue),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return buildEmptyState();
                  }

                  final completedCount = docs
                      .where((doc) => doc.data()['completed'] == true)
                      .length;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 5, 20, 12),
                        child: buildProgressCard(completedCount, docs.length),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 5, 22, 10),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Your Task List',
                                style: TextStyle(
                                  color: navy,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Text(
                              '${docs.length} tasks',
                              style: const TextStyle(
                                color: AppTheme.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 3, 20, 95),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            return buildTaskCard(doc.id, doc.data());
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskDetailPage extends StatelessWidget {
  final Map<String, dynamic> task;
  final Color priorityColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const TaskDetailPage({
    super.key,
    required this.task,
    required this.priorityColor,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  static const Color navy = Color(0xFF173B70);
  static const Color blue = Color(0xFF2874D0);
  static const Color pageColor = Color(0xFFF4F7FD);

  @override
  Widget build(BuildContext context) {
    final title = task['title']?.toString() ?? 'Untitled Task';
    final description =
        task['description']?.toString() ?? 'Tidak ada deskripsi.';
    final priority = task['priority']?.toString() ?? 'Medium';
    final completed = task['completed'] == true;

    final deadlineValue = task['deadline'];
    final deadline = deadlineValue is Timestamp ? deadlineValue.toDate() : null;

    return Scaffold(
      backgroundColor: pageColor,
      appBar: AppBar(
        backgroundColor: pageColor,
        foregroundColor: navy,
        elevation: 0,
        title: const Text(
          'Task Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: navy.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(19),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEAF2FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.task_alt_rounded,
                    size: 43,
                    color: blue,
                  ),
                ),
              ),
              const SizedBox(height: 25),
              _detailLabel('TASK TITLE'),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: navy,
                ),
              ),
              const SizedBox(height: 24),
              _detailLabel('DESCRIPTION'),
              const SizedBox(height: 8),
              Text(
                description.isEmpty ? 'Tidak ada deskripsi.' : description,
                style: const TextStyle(fontSize: 14, height: 1.6, color: navy),
              ),
              const SizedBox(height: 24),
              const Divider(color: Color(0xFFEDF1F7)),
              const SizedBox(height: 18),
              _detailLabel('PRIORITY'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  priority,
                  style: TextStyle(
                    color: priorityColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _detailLabel('DEADLINE'),
              const SizedBox(height: 12),
              _deadlineRow(
                Icons.calendar_month_rounded,
                deadline == null
                    ? 'Belum ditentukan'
                    : '${deadline.day}/${deadline.month}/${deadline.year}',
              ),
              if (deadline != null) ...[
                const SizedBox(height: 12),
                _deadlineRow(
                  Icons.access_time_rounded,
                  TimeOfDay.fromDateTime(deadline).format(context),
                ),
              ],
              const SizedBox(height: 22),
              const Divider(color: Color(0xFFEDF1F7)),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: blue,
                value: completed,
                title: const Text(
                  'Task Completed',
                  style: TextStyle(color: navy, fontWeight: FontWeight.w600),
                ),
                onChanged: (value) {
                  if (value != null) onToggle(value);
                },
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Task'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete Task'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFFFD5D5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.grey,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.7,
      ),
    );
  }

  Widget _deadlineRow(IconData icon, String text) {
    return Row(
      children: [
        const SizedBox(width: 2),
        Icon(icon, color: blue, size: 20),
        const SizedBox(width: 11),
        Text(text, style: const TextStyle(color: navy, fontSize: 14)),
      ],
    );
  }
}
