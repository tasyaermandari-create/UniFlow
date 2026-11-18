import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class UniFlowBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const UniFlowBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  final List<IconData> icons = const [
    Icons.home_rounded,
    Icons.calendar_month_rounded,
    Icons.timer_rounded,
    Icons.task_alt_rounded,
    Icons.sticky_note_2_rounded,
    Icons.person_rounded,
  ];

  final List<String> labels = const [
    'Home',
    'Routine',
    'Focus',
    'Tasks',
    'Notes',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(icons.length, (index) {
            final isSelected = selectedIndex == index;

            return Expanded(
              child: InkWell(
                onTap: () => onItemSelected(index),
                borderRadius: BorderRadius.circular(15),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 5,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icons[index],
                        size: 25,
                        color: isSelected
                            ? AppTheme.primary
                            : const Color(0xFF8998B5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labels[index],
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected
                              ? AppTheme.primary
                              : const Color(0xFF8998B5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
