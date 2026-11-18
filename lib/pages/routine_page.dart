import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class RoutinePage extends StatefulWidget {
  const RoutinePage({super.key});

  @override
  State<RoutinePage> createState() => _RoutinePageState();
}

class _RoutinePageState extends State<RoutinePage> {
  final FirestoreService firestoreService = FirestoreService();

  static const Color blue = Color(0xFF2874D0);
  static const Color navy = Color(0xFF173B70);
  static const Color paleBlue = Color(0xFFEAF2FF);
  static const Color pageColor = Color(0xFFF4F7FD);

  DateTime selectedDate = DateTime.now();

  late Stream<QuerySnapshot<Map<String, dynamic>>> routinesStream;

  final List<String> weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  void initState() {
    super.initState();
    routinesStream = firestoreService.getRoutines(selectedDate);
  }

  BoxDecoration get raisedDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: const Color(0xFFEAF0FA)),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF315B91).withValues(alpha: 0.08),
        blurRadius: 18,
        offset: const Offset(0, 7),
      ),
    ],
  );

  void updateSelectedDate(DateTime date) {
    setState(() {
      selectedDate = date;
      routinesStream = firestoreService.getRoutines(date);
    });
  }

  String get monthName {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[selectedDate.month - 1]} ${selectedDate.year}';
  }

  DateTime get weekStart {
    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    ).subtract(Duration(days: selectedDate.weekday - 1));
  }

  void changeWeek(int amount) {
    final newDate = selectedDate.add(Duration(days: amount * 7));
    updateSelectedDate(newDate);
  }

  int notificationId(String documentId) {
    var hash = 0x811C9DC5;

    for (final unit in 'routine:$documentId'.codeUnits) {
      hash = (hash ^ unit) * 0x01000193;
      hash &= 0x7FFFFFFF;
    }

    return hash == 0 ? 1 : hash;
  }

  DateTime combineDateAndTime(DateTime date, String time) {
    final parts = time.split(':');

    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  // NOTIFIKASI ROUTINE
  // Notifikasi muncul 1 jam sebelum kegiatan dimulai.

  Future<void> updateRoutineReminder({
    required String routineId,
    required String title,
    required DateTime date,
    required String startTime,
  }) async {
    final id = notificationId(routineId);

    try {
      // Batalkan notifikasi sebelumnya.
      await NotificationService.instance.cancelNotification(id);

      // Tentukan waktu mulai kegiatan.
      final activityStart = combineDateAndTime(date, startTime);

      // Jadwalkan pengingat 1 jam sebelum kegiatan.
      final reminderTime = activityStart.subtract(const Duration(hours: 1));

      // Jangan jadwalkan jika waktu pengingat sudah lewat.
      if (!reminderTime.isAfter(DateTime.now())) {
        debugPrint('Waktu pengingat kegiatan $title sudah lewat.');
        return;
      }

      // Meminta izin notifikasi.
      final permissionGranted = await NotificationService.instance
          .requestPermission();

      if (!permissionGranted) {
        debugPrint('Izin notifikasi belum diberikan.');
        return;
      }

      // Jadwalkan notifikasi.
      await NotificationService.instance.scheduleRoutineReminder(
        routineId: id,
        routineTitle: title,
        startTime: reminderTime,
      );

      debugPrint('Notifikasi $title berhasil dijadwalkan pada $reminderTime');
    } catch (e) {
      debugPrint('Gagal menjadwalkan notifikasi routine: $e');
      rethrow;
    }
  }

  Color activityColor(String title) {
    final text = title.toLowerCase();

    if (text.contains('makan') ||
        text.contains('lunch') ||
        text.contains('breakfast')) {
      return const Color(0xFFE8A044);
    }

    if (text.contains('kuliah') || text.contains('class')) {
      return const Color(0xFF4385F5);
    }

    if (text.contains('belajar') || text.contains('study')) {
      return const Color(0xFF8B76D9);
    }

    if (text.contains('coding') || text.contains('programming')) {
      return const Color(0xFF35A779);
    }

    if (text.contains('istirahat') || text.contains('break')) {
      return const Color(0xFF36A9B5);
    }

    if (text.contains('tidur') || text.contains('sleep')) {
      return const Color(0xFF7889C9);
    }

    return blue;
  }

  IconData activityIcon(String title) {
    final text = title.toLowerCase();

    if (text.contains('makan') ||
        text.contains('lunch') ||
        text.contains('breakfast')) {
      return Icons.restaurant_rounded;
    }

    if (text.contains('kuliah') || text.contains('class')) {
      return Icons.menu_book_rounded;
    }

    if (text.contains('belajar') || text.contains('study')) {
      return Icons.edit_note_rounded;
    }

    if (text.contains('coding') || text.contains('programming')) {
      return Icons.laptop_mac_rounded;
    }

    if (text.contains('istirahat') || text.contains('break')) {
      return Icons.coffee_rounded;
    }

    if (text.contains('tidur') || text.contains('sleep')) {
      return Icons.bedtime_rounded;
    }

    return Icons.event_note_rounded;
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // TAMBAH DAN EDIT

  Future<void> addActivity({
    String? routineId,
    Map<String, dynamic>? routine,
  }) async {
    final routineDateValue = routine?['date'];

    final activityDate = routineDateValue is Timestamp
        ? routineDateValue.toDate()
        : selectedDate;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _RoutineActivityDialog(
          isEditing: routineId != null,
          routine: routine,
          initialDate: activityDate,
          onSave:
              ({
                required String title,
                required String subtitle,
                required String start,
                required String end,
                required DateTime date,
              }) async {
                String savedRoutineId;

                if (routineId != null) {
                  savedRoutineId = routineId;

                  await firestoreService.updateRoutine(
                    routineId: savedRoutineId,
                    title: title,
                    subtitle: subtitle,
                    startTime: start,
                    endTime: end,
                    date: date,
                  );
                } else {
                  savedRoutineId = await firestoreService.addRoutine(
                    title: title,
                    subtitle: subtitle,
                    startTime: start,
                    endTime: end,
                    date: date,
                  );
                }

                await updateRoutineReminder(
                  routineId: savedRoutineId,
                  title: title,
                  date: date,
                  startTime: start,
                );
              },
        );
      },
    );
  }

  // HAPUS AKTIVITAS

  Future<void> deleteActivity(String id) async {
    try {
      await firestoreService.deleteRoutine(id);

      try {
        await NotificationService.instance.cancelNotification(
          notificationId(id),
        );
      } catch (e) {
        debugPrint('Gagal membatalkan notifikasi: $e');
      }

      showMessage('Aktivitas berhasil dihapus');
    } catch (e) {
      showMessage('Gagal menghapus aktivitas: $e');
    }
  }

  // KARTU AKTIVITAS

  Widget activityCard({
    required String id,
    required Map<String, dynamic> item,
    required bool isLast,
  }) {
    final title = (item['title'] ?? 'Aktivitas').toString();
    final subtitle = (item['subtitle'] ?? '').toString();
    final start = (item['startTime'] ?? '').toString();
    final end = (item['endTime'] ?? '').toString();

    final color = activityColor(title);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 53,
            child: Padding(
              padding: const EdgeInsets.only(top: 17),
              child: Text(
                start,
                style: const TextStyle(
                  color: navy,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 19,
            child: Column(
              children: [
                const SizedBox(height: 18),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 7,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: const Color(0xFFDCE7FA)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(15),
              decoration: raisedDecoration,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(activityIcon(title), color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: navy,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF8795AA),
                            ),
                          ),
                        ],
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: blue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$start - $end',
                              style: const TextStyle(
                                fontSize: 10,
                                color: blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: Color(0xFF91A0B5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        addActivity(routineId: id, routine: item);
                      } else if (value == 'delete') {
                        deleteActivity(id);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 18),
                            SizedBox(width: 9),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.red,
                              size: 18,
                            ),
                            SizedBox(width: 9),
                            Text('Hapus'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // DAFTAR AKTIVITAS

  Widget buildActivityList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: routinesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(35),
            child: Center(child: CircularProgressIndicator(color: blue)),
          );
        }

        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: raisedDecoration,
            child: Text(
              'Gagal memuat aktivitas:\n${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final activities = snapshot.data?.docs.toList() ?? [];

        activities.sort((a, b) {
          final first = (a.data()['startTime'] ?? '').toString();
          final second = (b.data()['startTime'] ?? '').toString();
          return first.compareTo(second);
        });

        if (activities.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(25),
            decoration: raisedDecoration,
            child: const Column(
              children: [
                Icon(
                  Icons.event_note_rounded,
                  size: 48,
                  color: Color(0xFF9AB6DE),
                ),
                SizedBox(height: 12),
                Text(
                  'No activities yet!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Add your first daily activity.',
                  style: TextStyle(color: Color(0xFF8795AA), fontSize: 11),
                ),
              ],
            ),
          );
        }

        return Column(
          children: List.generate(activities.length, (index) {
            final doc = activities[index];

            return activityCard(
              id: doc.id,
              item: doc.data(),
              isLast: index == activities.length - 1,
            );
          }),
        );
      },
    );
  }

  // TAMPILAN UTAMA

  @override
  Widget build(BuildContext context) {
    return Container(
      color: pageColor,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Routine',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: navy,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Organize your day, one step at a time ✨',
              style: TextStyle(fontSize: 12, color: Color(0xFF8795AA)),
            ),
            const SizedBox(height: 24),

            // KALENDER
            Container(
              padding: const EdgeInsets.all(17),
              decoration: raisedDecoration,
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: paleBlue,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: blue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          monthName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: navy,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => changeWeek(-1),
                        icon: const Icon(
                          Icons.chevron_left_rounded,
                          color: blue,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => changeWeek(1),
                        icon: const Icon(
                          Icons.chevron_right_rounded,
                          color: blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: List.generate(7, (index) {
                      final date = weekStart.add(Duration(days: index));

                      final isSelected =
                          date.year == selectedDate.year &&
                          date.month == selectedDate.month &&
                          date.day == selectedDate.day;

                      final isToday =
                          date.year == DateTime.now().year &&
                          date.month == DateTime.now().month &&
                          date.day == DateTime.now().day;

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => updateSelectedDate(date),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: isSelected ? blue : Colors.transparent,
                              borderRadius: BorderRadius.circular(15),
                              border: !isSelected && isToday
                                  ? Border.all(
                                      color: blue.withValues(alpha: 0.4),
                                    )
                                  : null,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  weekdays[index],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white70
                                        : const Color(0xFF91A0B5),
                                  ),
                                ),
                                const SizedBox(height: 9),
                                Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : navy,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white
                                        : isToday
                                        ? blue
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 27),

            // JUDUL AKTIVITAS
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Today's Activities",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Your planned schedule',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF8795AA),
                        ),
                      ),
                    ],
                  ),
                ),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: routinesStream,
                  builder: (context, snapshot) {
                    final count = snapshot.data?.docs.length ?? 0;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: paleBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count Activities',
                        style: const TextStyle(
                          fontSize: 10,
                          color: blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 18),

            buildActivityList(),

            const SizedBox(height: 10),

            // TOMBOL TAMBAH
            Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: blue.withValues(alpha: 0.20),
                    blurRadius: 13,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => addActivity(),
                icon: const Icon(Icons.add_rounded, size: 21),
                label: const Text(
                  'Add New Activity',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 25),

            const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.school_rounded,
                    color: Color(0xFFB7CBE8),
                    size: 24,
                  ),
                  SizedBox(height: 5),
                  Text(
                    'UniFlow',
                    style: TextStyle(
                      color: Color(0xFF8DA6C9),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Your Day, Your Flow.',
                    style: TextStyle(color: Color(0xFFAAB7C9), fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// DIALOG TAMBAH DAN EDIT AKTIVITAS
// ======================================================

class _RoutineActivityDialog extends StatefulWidget {
  final bool isEditing;
  final Map<String, dynamic>? routine;
  final DateTime initialDate;

  final Future<void> Function({
    required String title,
    required String subtitle,
    required String start,
    required String end,
    required DateTime date,
  })
  onSave;

  const _RoutineActivityDialog({
    required this.isEditing,
    required this.routine,
    required this.initialDate,
    required this.onSave,
  });

  @override
  State<_RoutineActivityDialog> createState() => _RoutineActivityDialogState();
}

class _RoutineActivityDialogState extends State<_RoutineActivityDialog> {
  static const Color blue = Color(0xFF2874D0);
  static const Color navy = Color(0xFF173B70);

  late final TextEditingController titleController;
  late final TextEditingController subtitleController;
  late final TextEditingController startController;
  late final TextEditingController endController;

  late DateTime activityDate;

  bool saving = false;

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(
      text: widget.routine?['title'] ?? '',
    );

    subtitleController = TextEditingController(
      text: widget.routine?['subtitle'] ?? '',
    );

    startController = TextEditingController(
      text: widget.routine?['startTime'] ?? '16:00',
    );

    endController = TextEditingController(
      text: widget.routine?['endTime'] ?? '17:00',
    );

    activityDate = widget.initialDate;
  }

  @override
  void dispose() {
    titleController.dispose();
    subtitleController.dispose();
    startController.dispose();
    endController.dispose();
    super.dispose();
  }

  InputDecoration inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: blue, size: 20),
      filled: true,
      fillColor: const Color(0xFFF4F7FD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5ECF7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: blue, width: 1.4),
      ),
    );
  }

  Future<void> saveActivity() async {
    final title = titleController.text.trim();
    final subtitle = subtitleController.text.trim();
    final start = startController.text.trim();
    final end = endController.text.trim();

    final timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

    if (title.isEmpty ||
        !timePattern.hasMatch(start) ||
        !timePattern.hasMatch(end)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi nama dan jam dengan format HH:mm yang benar'),
        ),
      );
      return;
    }

    if (start.compareTo(end) >= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jam selesai harus setelah jam mulai')),
      );
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      await widget.onSave(
        title: title,
        subtitle: subtitle,
        start: start,
        end: end,
        date: activityDate,
      );

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);

      final message = widget.isEditing
          ? 'Aktivitas berhasil diperbarui'
          : 'Aktivitas berhasil ditambahkan';

      Navigator.of(context).pop();

      messenger.showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        saving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan aktivitas: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        widget.isEditing ? 'Edit Activity' : 'New Activity',
        style: const TextStyle(
          color: navy,
          fontWeight: FontWeight.w800,
          fontSize: 19,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: inputDecoration(
                'Nama aktivitas',
                Icons.event_note_rounded,
              ),
            ),
            const SizedBox(height: 13),
            TextField(
              controller: subtitleController,
              decoration: inputDecoration(
                'Deskripsi aktivitas',
                Icons.description_rounded,
              ),
            ),
            const SizedBox(height: 13),
            TextField(
              controller: startController,
              keyboardType: TextInputType.datetime,
              decoration: inputDecoration(
                'Jam mulai (HH:mm)',
                Icons.access_time_rounded,
              ),
            ),
            const SizedBox(height: 13),
            TextField(
              controller: endController,
              keyboardType: TextInputType.datetime,
              decoration: inputDecoration(
                'Jam selesai (HH:mm)',
                Icons.timer_outlined,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FD),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5ECF7)),
              ),
              child: ListTile(
                leading: const Icon(Icons.calendar_month_rounded, color: blue),
                title: const Text(
                  'Tanggal aktivitas',
                  style: TextStyle(
                    fontSize: 12,
                    color: navy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${activityDate.day}/${activityDate.month}/${activityDate.year}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: blue),
                onTap: saving
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: activityDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );

                        if (picked != null && mounted) {
                          setState(() {
                            activityDate = picked;
                          });
                        }
                      },
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(),
          child: const Text(
            'Batal',
            style: TextStyle(color: Color(0xFF8795AA)),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: blue,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: saving ? null : saveActivity,
          child: saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(widget.isEditing ? 'Save Changes' : 'Add Activity'),
        ),
      ],
    );
  }
}
