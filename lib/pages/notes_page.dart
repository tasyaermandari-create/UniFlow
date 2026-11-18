import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/firestore_service.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final FirestoreService firestoreService = FirestoreService();
  final TextEditingController searchController = TextEditingController();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> notesStream;

  String searchQuery = '';

  final List<String> categories = ['Lecture', 'Assignment', 'Exam', 'Personal'];

  static const Color pageColor = Color(0xFFF4F7FD);
  static const Color navy = Color(0xFF173B70);
  static const Color blue = Color(0xFF2874D0);
  static const Color paleBlue = Color(0xFFEAF2FF);

  @override
  void initState() {
    super.initState();
    notesStream = firestoreService.getNotes();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Color categoryColor(String category) {
    switch (category) {
      case 'Lecture':
        return const Color(0xFF4385F5);
      case 'Assignment':
        return const Color(0xFF6599F5);
      case 'Exam':
        return const Color(0xFF326CCB);
      default:
        return const Color(0xFF8BB5F5);
    }
  }

  IconData categoryIcon(String category) {
    switch (category) {
      case 'Lecture':
        return Icons.menu_book_rounded;
      case 'Assignment':
        return Icons.assignment_rounded;
      case 'Exam':
        return Icons.quiz_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: blue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> openNoteDialog({
    String? noteId,
    Map<String, dynamic>? note,
  }) async {
    if (!mounted) return;

    final isEditing = noteId != null;

    final titleController = TextEditingController(
      text: note?['title']?.toString() ?? '',
    );

    final contentController = TextEditingController(
      text: note?['content']?.toString() ?? '',
    );

    String category = note?['category']?.toString() ?? 'Lecture';

    if (!categories.contains(category)) {
      category = 'Lecture';
    }

    bool saving = false;
    String? errorMessage;

    try {
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
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
                      child: const Icon(
                        Icons.sticky_note_2_rounded,
                        color: blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEditing ? 'Edit Note' : 'Create New Note',
                        style: const TextStyle(
                          color: navy,
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
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
                        enabled: !saving,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _inputDecoration(
                          label: 'Note Title',
                          hint: 'Example: Database Systems',
                          icon: Icons.title_rounded,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: contentController,
                        enabled: !saving,
                        maxLines: 6,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _inputDecoration(
                          label: 'Note Content',
                          hint: 'Write your study notes...',
                          icon: Icons.edit_note_rounded,
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        decoration: _inputDecoration(
                          label: 'Category',
                          icon: Icons.category_rounded,
                        ),
                        items: categories.map((item) {
                          return DropdownMenuItem<String>(
                            value: item,
                            child: Text(item),
                          );
                        }).toList(),
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setDialogState(() {
                                    category = value;
                                  });
                                }
                              },
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEEEE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop(false);
                          },
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
                    onPressed: saving
                        ? null
                        : () async {
                            final title = titleController.text.trim();
                            final content = contentController.text.trim();

                            if (title.isEmpty || content.isEmpty) {
                              setDialogState(() {
                                errorMessage =
                                    'Please complete the title and content.';
                              });
                              return;
                            }

                            setDialogState(() {
                              saving = true;
                              errorMessage = null;
                            });

                            try {
                              if (isEditing) {
                                await firestoreService.updateNote(
                                  noteId: noteId,
                                  title: title,
                                  content: content,
                                  category: category,
                                );
                              } else {
                                await firestoreService.addNote(
                                  title: title,
                                  content: content,
                                  category: category,
                                );
                              }

                              if (!dialogContext.mounted) return;

                              Navigator.of(dialogContext).pop(true);
                            } catch (e) {
                              debugPrint('Gagal menyimpan catatan: $e');

                              if (!dialogContext.mounted) return;

                              setDialogState(() {
                                saving = false;
                                errorMessage =
                                    'Gagal menyimpan catatan. Periksa koneksi dan coba lagi.';
                              });
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(isEditing ? 'Save Note' : 'Create Note'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (!mounted) return;

      if (saved == true) {
        showMessage(
          isEditing ? 'Note updated successfully' : 'Note created successfully',
        );
      }
    } finally {
      titleController.dispose();
      contentController.dispose();
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: blue),
      filled: true,
      fillColor: pageColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: blue, width: 1.3),
      ),
    );
  }

  Future<void> deleteNote(String noteId) async {
    try {
      await firestoreService.deleteNote(noteId);
      showMessage('Note deleted successfully');
    } catch (e) {
      debugPrint('Gagal menghapus catatan: $e');
      showMessage('Failed to delete note. Please try again.');
    }
  }

  Future<void> confirmDelete(String noteId) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete Note?',
            style: TextStyle(color: navy, fontWeight: FontWeight.bold),
          ),
          content: const Text('Are you sure you want to delete this note?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await deleteNote(noteId);
    }
  }

  void openNoteDetail(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final note = doc.data();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteDetailPage(
          note: note,
          categoryColor: categoryColor(
            (note['category'] ?? 'Lecture').toString(),
          ),
          categoryIcon: categoryIcon(
            (note['category'] ?? 'Lecture').toString(),
          ),
          formatDate: formatDate,
          onEdit: () {
            Navigator.pop(context);
            openNoteDialog(noteId: doc.id, note: note);
          },
          onDelete: () async {
            Navigator.pop(context);
            await confirmDelete(doc.id);
          },
        ),
      ),
    );
  }

  Widget noteCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final note = doc.data();

    final title = (note['title'] ?? 'Untitled').toString();
    final content = (note['content'] ?? '').toString();
    final category = (note['category'] ?? 'Lecture').toString();

    final createdAt = note['createdAt'];
    final date = createdAt is Timestamp ? createdAt.toDate() : DateTime.now();

    final color = categoryColor(category);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => openNoteDetail(doc),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: navy.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(categoryIcon(category), color: color, size: 23),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: navy,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppTheme.grey,
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      openNoteDialog(noteId: doc.id, note: note);
                    } else if (value == 'delete') {
                      confirmDelete(doc.id);
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
            const SizedBox(height: 15),
            Text(
              content,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.grey,
                fontSize: 13,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 15),
            const Divider(color: Color(0xFFEDF1F7)),
            const SizedBox(height: 9),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: AppTheme.grey,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      formatDate(date),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
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
              child: const Icon(
                Icons.sticky_note_2_rounded,
                size: 55,
                color: blue,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              searchQuery.isNotEmpty ? 'No Notes Found' : 'No Notes Yet',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: navy,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              searchQuery.isNotEmpty
                  ? 'Try searching with another keyword.'
                  : 'Create your first study note.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.grey, fontSize: 12),
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
        onPressed: () => openNoteDialog(),
        backgroundColor: blue,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Note',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Notes',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: navy,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Keep your knowledge organized.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.grey,
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
                          Icons.sticky_note_2_rounded,
                          color: blue,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: navy.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: searchController,
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search your notes...',
                        hintStyle: const TextStyle(
                          color: AppTheme.grey,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: blue,
                        ),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  searchController.clear();
                                  setState(() {
                                    searchQuery = '';
                                  });
                                },
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: AppTheme.grey,
                                ),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: blue, width: 1.2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: notesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Failed to load notes:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: blue),
                    );
                  }

                  final allNotes = snapshot.data?.docs ?? [];

                  final filteredNotes = allNotes.where((doc) {
                    final title = (doc.data()['title'] ?? '').toString();

                    return title.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    );
                  }).toList();

                  if (filteredNotes.isEmpty) {
                    return buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 5, 20, 95),
                    itemCount: filteredNotes.length,
                    itemBuilder: (context, index) {
                      return noteCard(filteredNotes[index]);
                    },
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

class NoteDetailPage extends StatelessWidget {
  final Map<String, dynamic> note;
  final Color categoryColor;
  final IconData categoryIcon;
  final String Function(DateTime) formatDate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const NoteDetailPage({
    super.key,
    required this.note,
    required this.categoryColor,
    required this.categoryIcon,
    required this.formatDate,
    required this.onEdit,
    required this.onDelete,
  });

  static const Color navy = Color(0xFF173B70);
  static const Color blue = Color(0xFF2874D0);
  static const Color pageColor = Color(0xFFF4F7FD);

  @override
  Widget build(BuildContext context) {
    final title = note['title']?.toString() ?? 'Untitled';
    final content = note['content']?.toString() ?? '';
    final category = note['category']?.toString() ?? 'Lecture';

    final createdAt = note['createdAt'];
    final date = createdAt is Timestamp ? createdAt.toDate() : DateTime.now();

    return Scaffold(
      backgroundColor: pageColor,
      appBar: AppBar(
        backgroundColor: pageColor,
        foregroundColor: navy,
        elevation: 0,
        title: const Text(
          'Note Details',
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
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(categoryIcon, size: 43, color: categoryColor),
                ),
              ),
              const SizedBox(height: 25),
              _detailLabel('NOTE TITLE'),
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
              const Divider(color: Color(0xFFEDF1F7)),
              const SizedBox(height: 18),
              _detailLabel('CATEGORY'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: categoryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _detailLabel('DATE CREATED'),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: blue,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    formatDate(date),
                    style: const TextStyle(color: navy, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: Color(0xFFEDF1F7)),
              const SizedBox(height: 18),
              _detailLabel('NOTE CONTENT'),
              const SizedBox(height: 12),
              SelectableText(
                content.isEmpty ? 'Tidak ada isi catatan.' : content,
                style: const TextStyle(color: navy, fontSize: 15, height: 1.8),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Note'),
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
                  label: const Text('Delete Note'),
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
}
