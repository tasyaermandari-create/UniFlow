import 'dart:async';

import 'package:flutter/material.dart';

import '../services/notification_service.dart';

class FocusPage extends StatefulWidget {
  const FocusPage({super.key});

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  static const int defaultFocusDuration = 25;
  static const int defaultBreakDuration = 5;

  static const int focusNotificationId = 900001;
  static const int breakNotificationId = 900002;

  static const Color blue = Color(0xFF2874D0);
  static const Color navy = Color(0xFF173B70);
  static const Color paleBlue = Color(0xFFEAF2FF);
  static const Color pageColor = Color(0xFFF4F7FD);
  static const Color green = Color(0xFF65B995);

  int focusDuration = defaultFocusDuration;
  int breakDuration = defaultBreakDuration;

  int remainingSeconds = defaultFocusDuration * 60;
  int completedSessions = 0;

  bool isRunning = false;
  bool isBreak = false;
  bool isFinishing = false;

  Timer? timer;
  DateTime? endTime;

  String get formattedTime {
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  double get progress {
    final total = (isBreak ? breakDuration : focusDuration) * 60;

    if (total <= 0) return 0;

    return ((total - remainingSeconds) / total).clamp(0.0, 1.0);
  }

  Color get activeColor => isBreak ? green : blue;

  // CANCEL NOTIFICATION

  Future<void> cancelTimerNotification() async {
    try {
      await NotificationService.instance.cancelNotification(
        focusNotificationId,
      );

      await NotificationService.instance.cancelNotification(
        breakNotificationId,
      );
    } catch (e) {
      debugPrint('Gagal membatalkan notifikasi: $e');
    }
  }

  // SCHEDULE NOTIFICATION

  Future<void> scheduleTimerNotification() async {
    try {
      final permissionGranted = await NotificationService.instance
          .requestPermission();

      if (!permissionGranted || !mounted || !isRunning) return;

      final notificationTime = endTime;

      if (notificationTime == null) return;

      await NotificationService.instance.scheduleNotification(
        id: isBreak ? breakNotificationId : focusNotificationId,
        title: isBreak ? 'Waktu Istirahat Selesai!' : 'Sesi Fokus Selesai!',
        body: isBreak
            ? 'Yuk kembali fokus dan lanjutkan aktivitasmu.'
            : 'Selamat! Waktunya beristirahat sejenak.',
        scheduledDate: notificationTime,
      );

      debugPrint('Notifikasi dijadwalkan: $notificationTime');
    } catch (e) {
      debugPrint('Gagal menjadwalkan notifikasi: $e');
    }
  }

  // EDIT TIMER

  Future<void> editTimerSettings() async {
    if (isRunning || !mounted) return;

    try {
      final result = await showDialog<Map<String, int>>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return _EditTimerDialog(
            focusDuration: focusDuration,
            breakDuration: breakDuration,
          );
        },
      );

      if (!mounted || result == null) return;

      final newFocus = result['focus'];
      final newBreak = result['break'];

      if (newFocus == null || newBreak == null) return;

      setState(() {
        focusDuration = newFocus;
        breakDuration = newBreak;
        remainingSeconds = (isBreak ? breakDuration : focusDuration) * 60;
      });

      showMessage('Pengaturan timer berhasil diperbarui!');
    } catch (e, stackTrace) {
      debugPrint('Error edit timer: $e');
      debugPrint('$stackTrace');

      if (mounted) {
        showMessage('Gagal mengubah timer. Silakan coba lagi.');
      }
    }
  }

  // SHOW MESSAGE

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: navy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // START TIMER

  Future<void> startTimer() async {
    if (isRunning || !mounted || isFinishing) return;

    if (remainingSeconds <= 0) return;

    endTime = DateTime.now().add(Duration(seconds: remainingSeconds));

    setState(() {
      isRunning = true;
    });

    unawaited(scheduleTimerNotification());

    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 1), (timerInstance) {
      if (!mounted) {
        timerInstance.cancel();
        return;
      }

      final difference = endTime?.difference(DateTime.now());

      if (difference == null || difference.inMilliseconds <= 0) {
        timerInstance.cancel();
        unawaited(finishSession());
        return;
      }

      final secondsLeft = (difference.inMilliseconds / 1000).ceil();

      setState(() {
        remainingSeconds = secondsLeft;
      });
    });
  }

  // FINISH SESSION

  Future<void> finishSession() async {
    if (!mounted || !isRunning || isFinishing) return;

    isFinishing = true;
    timer?.cancel();

    final finishedFocus = !isBreak;

    final finishedNotificationId = isBreak
        ? breakNotificationId
        : focusNotificationId;

    endTime = null;

    setState(() {
      isRunning = false;

      if (finishedFocus) {
        completedSessions++;
      }

      isBreak = !isBreak;

      remainingSeconds = (isBreak ? breakDuration : focusDuration) * 60;
    });

    try {
      await NotificationService.instance.cancelNotification(
        finishedNotificationId,
      );

      await NotificationService.instance.showNotification(
        id: finishedNotificationId,
        title: finishedFocus
            ? 'Sesi Fokus Selesai!'
            : 'Waktu Istirahat Selesai!',
        body: finishedFocus
            ? 'Selamat! Waktunya beristirahat sejenak.'
            : 'Yuk kembali fokus dan lanjutkan aktivitasmu.',
      );
    } catch (e) {
      debugPrint('Gagal menampilkan notifikasi: $e');
    }

    if (mounted) {
      showMessage(
        finishedFocus
            ? 'Sesi fokus selesai! Waktunya istirahat 🎉'
            : 'Waktu istirahat selesai! Yuk fokus kembali 💪',
      );
    }

    isFinishing = false;
  }

  // PAUSE TIMER

  Future<void> pauseTimer() async {
    if (!isRunning) return;

    timer?.cancel();

    final difference = endTime?.difference(DateTime.now());

    endTime = null;

    if (!mounted) return;

    setState(() {
      isRunning = false;

      if (difference != null) {
        remainingSeconds = difference.inMilliseconds <= 0
            ? 0
            : (difference.inMilliseconds / 1000).ceil();
      }
    });

    await cancelTimerNotification();
  }

  // RESET TIMER

  Future<void> resetTimer() async {
    timer?.cancel();
    endTime = null;

    if (!mounted) return;

    setState(() {
      isRunning = false;
      isBreak = false;
      remainingSeconds = focusDuration * 60;
    });

    await cancelTimerNotification();
  }

  // SWITCH MODE

  Future<void> switchMode(bool breakMode) async {
    if (isBreak == breakMode && !isRunning) return;

    timer?.cancel();
    endTime = null;

    if (!mounted) return;

    setState(() {
      isRunning = false;
      isBreak = breakMode;
      remainingSeconds = (breakMode ? breakDuration : focusDuration) * 60;
    });

    await cancelTimerNotification();
  }

  // DISPOSE

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  // CARD DECORATION

  BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: navy.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 7),
        ),
      ],
    );
  }

  // BUILD

  @override
  Widget build(BuildContext context) {
    return Container(
      color: pageColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Focus Mode',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: navy,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Stay focused and make progress!',
                        style: TextStyle(
                          color: Color(0xFF8291A8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  child: IconButton(
                    onPressed: isRunning ? null : editTimerSettings,
                    tooltip: 'Edit Timer',
                    icon: const Icon(
                      Icons.settings_rounded,
                      color: blue,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // COMPLETED SESSIONS
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(19),
              decoration: cardDecoration(),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: paleBlue,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      color: blue,
                      size: 29,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Completed Sessions',
                          style: TextStyle(
                            color: Color(0xFF8291A8),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$completedSessions sessions',
                          style: const TextStyle(
                            color: navy,
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F5FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: Color(0xFFE8B34D),
                      size: 23,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // MODE SELECTOR
            Container(
              padding: const EdgeInsets.all(6),
              decoration: cardDecoration(),
              child: Row(
                children: [
                  Expanded(
                    child: modeButton(
                      title: 'Focus',
                      icon: Icons.menu_book_rounded,
                      selected: !isBreak,
                      onTap: () => switchMode(false),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: modeButton(
                      title: 'Break',
                      icon: Icons.coffee_rounded,
                      selected: isBreak,
                      onTap: () => switchMode(true),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 27),

            // TIMER CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: cardDecoration(),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isBreak ? const Color(0xFFEAF8F1) : paleBlue,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isBreak
                              ? Icons.coffee_rounded
                              : Icons.auto_awesome_rounded,
                          size: 15,
                          color: activeColor,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          isRunning
                              ? 'SESSION IN PROGRESS'
                              : isBreak
                              ? 'BREAK TIME'
                              : 'FOCUS TIME',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1,
                            fontWeight: FontWeight.bold,
                            color: activeColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 27),

                  // CIRCULAR TIMER
                  Center(
                    child: SizedBox(
                      width: 245,
                      height: 245,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 245,
                            height: 245,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 12,
                              strokeCap: StrokeCap.round,
                              backgroundColor: paleBlue,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                activeColor,
                              ),
                            ),
                          ),
                          Container(
                            width: 215,
                            height: 215,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isBreak
                                  ? const Color(0xFFF4FBF7)
                                  : const Color(0xFFF7FAFF),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isBreak
                                      ? Icons.coffee_rounded
                                      : Icons.menu_book_rounded,
                                  size: 33,
                                  color: activeColor,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  formattedTime,
                                  style: const TextStyle(
                                    fontSize: 46,
                                    fontWeight: FontWeight.bold,
                                    color: navy,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  isBreak ? 'Take a break' : 'Stay focused',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF8291A8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 23),

                  Text(
                    'Focus: $focusDuration min  •  Break: $breakDuration min',
                    style: const TextStyle(
                      color: Color(0xFF8291A8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 27),

                  // TIMER BUTTONS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 53,
                        height: 53,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4FA),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: IconButton(
                          onPressed: resetTimer,
                          icon: const Icon(Icons.refresh_rounded),
                          iconSize: 25,
                          color: const Color(0xFF8291A8),
                          tooltip: 'Reset',
                        ),
                      ),

                      const SizedBox(width: 14),

                      SizedBox(
                        width: 165,
                        height: 53,
                        child: ElevatedButton.icon(
                          onPressed: isRunning ? pauseTimer : startTimer,
                          icon: Icon(
                            isRunning
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                          label: Text(
                            isRunning ? 'Pause' : 'Start Focus',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: activeColor,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shadowColor: activeColor.withValues(alpha: 0.25),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // FOCUS TIPS
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 39,
                        height: 39,
                        decoration: BoxDecoration(
                          color: paleBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.lightbulb_rounded,
                          color: blue,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Focus Tips',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: navy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 17),

                  tipItem('Choose one task to complete.'),
                  tipItem('Keep distractions away.'),
                  tipItem('Focus on your selected duration.'),
                  tipItem('Take a break after focusing.'),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // FOOTER
            const Center(
              child: Text(
                'UniFlow • Your Day, Your Flow.',
                style: TextStyle(
                  color: Color(0xFF9AA9BE),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // MODE BUTTON

  Widget modeButton({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? blue : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: blue.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? Colors.white : const Color(0xFF8291A8),
            ),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF8291A8),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // FOCUS TIP ITEM

  Widget tipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF65B995),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF8291A8),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// EDIT TIMER DIALOG

class _EditTimerDialog extends StatefulWidget {
  final int focusDuration;
  final int breakDuration;

  const _EditTimerDialog({
    required this.focusDuration,
    required this.breakDuration,
  });

  @override
  State<_EditTimerDialog> createState() => _EditTimerDialogState();
}

class _EditTimerDialogState extends State<_EditTimerDialog> {
  late final TextEditingController focusController;
  late final TextEditingController breakController;

  String? validationError;

  @override
  void initState() {
    super.initState();

    focusController = TextEditingController(
      text: widget.focusDuration.toString(),
    );

    breakController = TextEditingController(
      text: widget.breakDuration.toString(),
    );
  }

  void saveTimer() {
    final focus = int.tryParse(focusController.text.trim());
    final breakTime = int.tryParse(breakController.text.trim());

    if (focus == null ||
        breakTime == null ||
        focus < 1 ||
        focus > 180 ||
        breakTime < 1 ||
        breakTime > 180) {
      setState(() {
        validationError = 'Masukkan durasi antara 1 sampai 180 menit.';
      });
      return;
    }

    Navigator.of(context).pop({'focus': focus, 'break': breakTime});
  }

  @override
  void dispose() {
    focusController.dispose();
    breakController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        'Edit Timer',
        style: TextStyle(color: Color(0xFF173B70), fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: focusController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Focus Duration',
              suffixText: 'minutes',
              prefixIcon: const Icon(
                Icons.menu_book_rounded,
                color: Color(0xFF2874D0),
              ),
              filled: true,
              fillColor: const Color(0xFFF4F7FD),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: breakController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Break Duration',
              suffixText: 'minutes',
              prefixIcon: const Icon(
                Icons.coffee_rounded,
                color: Color(0xFF65B995),
              ),
              filled: true,
              fillColor: const Color(0xFFF4F7FD),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Durasi harus antara 1 sampai 180 menit.',
            style: TextStyle(color: Color(0xFF8291A8), fontSize: 12),
          ),
          if (validationError != null) ...[
            const SizedBox(height: 10),
            Text(
              validationError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Color(0xFF8291A8)),
          ),
        ),
        ElevatedButton(
          onPressed: saveTimer,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2874D0),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
