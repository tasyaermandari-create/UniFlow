import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/bottom_navbar.dart';
import '../services/firestore_service.dart';

import 'routine_page.dart';
import 'focus_page.dart';
import 'tasks_page.dart';
import 'notes_page.dart';
import 'profile_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedIndex = 0;

  final FirestoreService firestoreService = FirestoreService();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> tasksStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> routinesStream;

  final DateTime dashboardDate = DateTime.now();

  static const Color blue = Color(0xFF2874D0);
  static const Color navy = Color(0xFF173B70);
  static const Color paleBlue = Color(0xFFEAF2FF);
  static const Color pageColor = Color(0xFFF4F7FD);

  @override
  void initState() {
    super.initState();
    tasksStream = firestoreService.getTasks();
    routinesStream = firestoreService.getRoutines(dashboardDate);
  }

  String get studentName {
    final name = FirebaseAuth.instance.currentUser?.displayName;
    return name == null || name.trim().isEmpty ? 'Student' : name;
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
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.9),
        blurRadius: 5,
        offset: const Offset(-2, -2),
      ),
    ],
  );

  // =========================
  // DASHBOARD HOME
  // =========================

  Widget buildHome() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WELCOME BACK',
                      style: TextStyle(
                        color: blue,
                        fontSize: 11,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Hello, $studentName 👋',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Ready to make today productive?',
                      style: TextStyle(color: Color(0xFF8795AA), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: [
                    BoxShadow(
                      color: blue.withValues(alpha: 0.10),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: blue,
                  size: 25,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // CLOCK
          const _LiveClockCard(),

          const SizedBox(height: 27),

          // PROGRESS TITLE
          _sectionTitle(
            'Today\'s Progress',
            'Your daily achievement',
            Icons.trending_up_rounded,
          ),

          const SizedBox(height: 14),

          // PROGRESS CARD
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: tasksStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return errorCard(snapshot.error.toString());
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: blue),
                );
              }

              final tasks = snapshot.data?.docs ?? [];

              final completedTasks = tasks
                  .where((doc) => doc.data()['completed'] == true)
                  .length;

              final totalTasks = tasks.length;
              final pendingTasks = totalTasks - completedTasks;

              final progress = totalTasks == 0
                  ? 0.0
                  : completedTasks / totalTasks;

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: raisedDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: paleBlue,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: blue,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Study Progress',
                            style: TextStyle(
                              color: navy,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          '${(progress * 100).round()}%',
                          style: const TextStyle(
                            color: blue,
                            fontWeight: FontWeight.w800,
                            fontSize: 21,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 11,
                        backgroundColor: const Color(0xFFE8EFFA),
                        valueColor: const AlwaysStoppedAnimation(blue),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _progressInfo(
                          Icons.check_circle_rounded,
                          '$completedTasks Completed',
                          const Color(0xFF35A779),
                        ),
                        const Spacer(),
                        _progressInfo(
                          Icons.pending_actions_rounded,
                          '$pendingTasks Pending',
                          const Color(0xFFEC9B43),
                        ),
                      ],
                    ),
                    if (totalTasks == 0) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Add your first task to start tracking progress.',
                        style: TextStyle(
                          color: Color(0xFF8795AA),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 28),

          // TODAY'S ACTIVITY
          Row(
            children: [
              Expanded(
                child: _sectionTitle(
                  'Today\'s Activity',
                  'Your daily routine',
                  Icons.calendar_month_rounded,
                ),
              ),
              _seeAllButton(1),
            ],
          ),

          const SizedBox(height: 14),

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: routinesStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return errorCard(snapshot.error.toString());
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: blue),
                );
              }

              final activities = snapshot.data?.docs.toList() ?? [];

              activities.sort((a, b) {
                final first = (a.data()['startTime'] ?? '').toString();
                final second = (b.data()['startTime'] ?? '').toString();
                return first.compareTo(second);
              });

              if (activities.isEmpty) {
                return emptyCard(
                  icon: Icons.event_note_rounded,
                  title: 'No activities today',
                  subtitle: 'Add your daily routine to get started.',
                );
              }

              return Column(
                children: activities.take(3).map((doc) {
                  final item = doc.data();

                  final title = (item['title'] ?? 'Activity').toString();
                  final subtitle = (item['subtitle'] ?? '').toString();
                  final start = (item['startTime'] ?? '').toString();
                  final end = (item['endTime'] ?? '').toString();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: activityCard(
                      icon: Icons.event_note_rounded,
                      title: title,
                      subtitle: subtitle,
                      time: '$start - $end',
                      color: const Color(0xFF4385F5),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 16),

          // UPCOMING TASKS
          Row(
            children: [
              Expanded(
                child: _sectionTitle(
                  'Upcoming Tasks',
                  'Things you need to do',
                  Icons.assignment_rounded,
                ),
              ),
              _seeAllButton(3),
            ],
          ),

          const SizedBox(height: 14),

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: tasksStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return errorCard(snapshot.error.toString());
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: blue),
                );
              }

              final upcomingTasks =
                  snapshot.data?.docs
                      .where((doc) => doc.data()['completed'] != true)
                      .toList() ??
                  [];

              upcomingTasks.sort((a, b) {
                final dateA =
                    (a.data()['deadline'] as Timestamp?)?.toDate() ??
                    DateTime(2100);

                final dateB =
                    (b.data()['deadline'] as Timestamp?)?.toDate() ??
                    DateTime(2100);

                return dateA.compareTo(dateB);
              });

              if (upcomingTasks.isEmpty) {
                return emptyCard(
                  icon: Icons.task_alt_rounded,
                  title: 'No upcoming tasks',
                  subtitle: 'Add your first task to get started.',
                );
              }

              return Column(
                children: upcomingTasks.take(3).map((doc) {
                  final task = doc.data();
                  final deadline = (task['deadline'] as Timestamp?)?.toDate();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: taskCard(
                      title: (task['title'] ?? 'Untitled Task').toString(),
                      subtitle: deadline == null
                          ? 'Deadline not set'
                          : 'Deadline: ${deadline.day}/${deadline.month}/${deadline.year}',
                      icon: Icons.assignment_rounded,
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 15),

          // FOOTER
          Center(
            child: Column(
              children: [
                const Icon(
                  Icons.school_rounded,
                  color: Color(0xFFB7CBE8),
                  size: 25,
                ),
                const SizedBox(height: 5),
                const Text(
                  'UniFlow',
                  style: TextStyle(
                    color: Color(0xFF8DA6C9),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Your Day, Your Flow.',
                  style: TextStyle(color: Color(0xFFAAB7C9), fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // SECTION TITLE
  // =========================

  Widget _sectionTitle(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: paleBlue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: blue, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: navy,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF91A0B5), fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _seeAllButton(int index) {
    return TextButton(
      onPressed: () {
        setState(() {
          selectedIndex = index;
        });
      },
      child: const Text(
        'See all',
        style: TextStyle(
          color: blue,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _progressInfo(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF8795AA),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // =========================
  // ERROR CARD
  // =========================

  Widget errorCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: raisedDecoration,
      child: Text(
        'Gagal memuat data:\n$message',
        style: const TextStyle(color: Colors.red, fontSize: 12),
      ),
    );
  }

  // =========================
  // EMPTY CARD
  // =========================

  Widget emptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      decoration: raisedDecoration,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: paleBlue,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 30, color: blue),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: navy,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Color(0xFF8795AA)),
          ),
        ],
      ),
    );
  }

  // =========================
  // ACTIVITY CARD
  // =========================

  Widget activityCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: raisedDecoration,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: navy,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle.isEmpty ? 'Daily activity' : subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8795AA),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: paleBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              time,
              style: const TextStyle(
                color: blue,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // TASK CARD
  // =========================

  Widget taskCard({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: raisedDecoration,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.circle_outlined,
              color: Color(0xFFE9A13B),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: navy,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8795AA),
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, color: const Color(0xFF9AB6DE), size: 21),
        ],
      ),
    );
  }

  // =========================
  // MAIN BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      buildHome(),
      const RoutinePage(),
      const FocusPage(),
      const TasksPage(),
      const NotesPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: pageColor,
      body: SafeArea(
        child: IndexedStack(index: selectedIndex, children: pages),
      ),
      bottomNavigationBar: UniFlowBottomNavBar(
        selectedIndex: selectedIndex,
        onItemSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
      ),
    );
  }
}

// =========================
// LIVE CLOCK CARD
// =========================

class _LiveClockCard extends StatefulWidget {
  const _LiveClockCard();

  @override
  State<_LiveClockCard> createState() => _LiveClockCardState();
}

class _LiveClockCardState extends State<_LiveClockCard> {
  late DateTime currentTime;
  Timer? clockTimer;

  @override
  void initState() {
    super.initState();

    currentTime = DateTime.now();

    clockTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!mounted) return;

      setState(() {
        currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    clockTimer?.cancel();
    super.dispose();
  }

  String get formattedTime {
    return '${currentTime.hour.toString().padLeft(2, '0')}:'
        '${currentTime.minute.toString().padLeft(2, '0')}';
  }

  String get formattedDate {
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

    return '${currentTime.day} '
        '${months[currentTime.month - 1]} '
        '${currentTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(23),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4389E8), Color(0xFF2465BD), Color(0xFF194B91)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2874D0).withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -30,
            child: Container(
              width: 125,
              height: 125,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -55,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 19),
                  SizedBox(width: 9),
                  Text(
                    'YOUR DAILY OVERVIEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      letterSpacing: 1.7,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Text(
                formattedTime,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formattedDate,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.17),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.school_rounded, color: Colors.white, size: 17),
                    SizedBox(width: 8),
                    Text(
                      'Make every moment count!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
