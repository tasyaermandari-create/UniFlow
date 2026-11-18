import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // UID PENGGUNA YANG LOGIN
  String get _uid {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Pengguna belum login');
    }

    return user.uid;
  }

  // =========================
  // USER
  // =========================

  Future<void> saveUser({required String name, required String email}) async {
    await _db.collection('users').doc(_uid).set({
      'userId': _uid,
      'name': name,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUser() {
    return _db.collection('users').doc(_uid).get();
  }

  // SIMPAN FOTO PROFIL BASE64
  Future<void> saveProfilePhoto(String photoBase64) async {
    await _db.collection('users').doc(_uid).set({
      'photoBase64': photoBase64,
      'photoUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // HAPUS FOTO PROFIL
  Future<void> deleteProfilePhoto() async {
    await _db.collection('users').doc(_uid).update({
      'photoBase64': FieldValue.delete(),
      'photoUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  // =========================
  // TASKS
  // =========================

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _db.collection('users').doc(_uid).collection('tasks');

  Stream<QuerySnapshot<Map<String, dynamic>>> getTasks() {
    return _tasks.orderBy('createdAt', descending: true).snapshots();
  }

  Future<String> addTask({
    required String title,
    required String description,
    required String priority,
    required DateTime deadline,
  }) async {
    final doc = await _tasks.add({
      'title': title,
      'description': description,
      'priority': priority,
      'deadline': Timestamp.fromDate(deadline),
      'completed': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  Future<void> updateTask({
    required String taskId,
    required String title,
    required String description,
    required String priority,
    required DateTime deadline,
    required bool completed,
  }) async {
    await _tasks.doc(taskId).update({
      'title': title,
      'description': description,
      'priority': priority,
      'deadline': Timestamp.fromDate(deadline),
      'completed': completed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleTask({
    required String taskId,
    required bool completed,
  }) async {
    await _tasks.doc(taskId).update({'completed': completed});
  }

  Future<void> deleteTask(String taskId) async {
    await _tasks.doc(taskId).delete();
  }

  // =========================
  // NOTES
  // =========================

  CollectionReference<Map<String, dynamic>> get _notes =>
      _db.collection('users').doc(_uid).collection('notes');

  Stream<QuerySnapshot<Map<String, dynamic>>> getNotes() {
    return _notes.orderBy('createdAt', descending: true).snapshots();
  }

  Future<String> addNote({
    required String title,
    required String content,
    required String category,
  }) async {
    final doc = await _notes.add({
      'title': title,
      'content': content,
      'category': category,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  Future<void> updateNote({
    required String noteId,
    required String title,
    required String content,
    required String category,
  }) async {
    await _notes.doc(noteId).update({
      'title': title,
      'content': content,
      'category': category,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteNote(String noteId) async {
    await _notes.doc(noteId).delete();
  }

  // =========================
  // ROUTINES
  // =========================

  CollectionReference<Map<String, dynamic>> get _routines =>
      _db.collection('users').doc(_uid).collection('routines');

  String _routineDateKey(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getRoutines(DateTime date) {
    return _routines
        .where('dateKey', isEqualTo: _routineDateKey(date))
        .snapshots();
  }

  Future<String> addRoutine({
    required String title,
    required String subtitle,
    required String startTime,
    required String endTime,
    required DateTime date,
  }) async {
    final doc = await _routines.add({
      'title': title,
      'subtitle': subtitle,
      'startTime': startTime,
      'endTime': endTime,
      'dateKey': _routineDateKey(date),
      'date': Timestamp.fromDate(date),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  Future<void> updateRoutine({
    required String routineId,
    required String title,
    required String subtitle,
    required String startTime,
    required String endTime,
    required DateTime date,
  }) async {
    await _routines.doc(routineId).update({
      'title': title,
      'subtitle': subtitle,
      'startTime': startTime,
      'endTime': endTime,
      'dateKey': _routineDateKey(date),
      'date': Timestamp.fromDate(date),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteRoutine(String routineId) async {
    await _routines.doc(routineId).delete();
  }
}
