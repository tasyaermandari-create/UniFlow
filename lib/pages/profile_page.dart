import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import 'welcome_page.dart';

// ============================================================
// PROFILE PAGE
// ============================================================

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirestoreService firestoreService = FirestoreService();
  final FirebaseAuth auth = FirebaseAuth.instance;

  late Future<DocumentSnapshot<Map<String, dynamic>>> userFuture;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> tasksStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> notesStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> routinesStream;

  bool isUpdatingName = false;
  bool isLoggingOut = false;
  bool isUpdatingPhoto = false;

  @override
  void initState() {
    super.initState();

    userFuture = firestoreService.getUser();

    tasksStream = firestoreService.getTasks();
    notesStream = firestoreService.getNotes();
    routinesStream = firestoreService.getRoutines(DateTime.now());
  }

  void refreshProfile() {
    if (!mounted) return;

    setState(() {
      userFuture = firestoreService.getUser();
    });
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.primary),
    );
  }

  // ============================================================
  // PROFILE PHOTO (BASE64)
  // ============================================================

  Future<void> pickAndSaveProfilePhoto() async {
    if (isUpdatingPhoto || !mounted) return;

    try {
      final XFile? pickedImage = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 35,
        maxWidth: 400,
        maxHeight: 400,
        requestFullMetadata: false,
      );

      if (pickedImage == null || !mounted) return;

      final imageBytes = await pickedImage.readAsBytes();

      // Batas aman untuk menghindari dokumen Firestore terlalu besar.
      if (imageBytes.length > 400 * 1024) {
        showMessage('Ukuran foto masih terlalu besar. Pilih foto lain.');
        return;
      }

      final photoBase64 = base64Encode(imageBytes);

      setState(() {
        isUpdatingPhoto = true;
      });

      await firestoreService.saveProfilePhoto(photoBase64);

      if (!mounted) return;

      refreshProfile();
      showMessage('Foto profil berhasil diperbarui!');
    } catch (e) {
      debugPrint('Gagal memperbarui foto profil: $e');
      showMessage('Gagal memperbarui foto. Silakan coba lagi.');
    } finally {
      if (mounted) {
        setState(() {
          isUpdatingPhoto = false;
        });
      }
    }
  }

  Future<void> deleteProfilePhoto() async {
    if (isUpdatingPhoto || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Foto Profil?'),
        content: const Text(
          'Foto profil akan dihapus dan diganti dengan ikon pengguna.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      isUpdatingPhoto = true;
    });

    try {
      await firestoreService.deleteProfilePhoto();

      if (!mounted) return;

      refreshProfile();
      showMessage('Foto profil berhasil dihapus.');
    } catch (e) {
      debugPrint('Gagal menghapus foto profil: $e');
      showMessage('Gagal menghapus foto profil. Silakan coba lagi.');
    } finally {
      if (mounted) {
        setState(() {
          isUpdatingPhoto = false;
        });
      }
    }
  }

  // ============================================================
  // NOTIFICATION SETTINGS
  // ============================================================

  Future<void> openNotificationSettings() async {
    String? fcmToken;
    bool isLoading = false;

    String statusMessage = 'Aktifkan izin untuk mendapatkan token FCM.';

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> activateFCM() async {
              if (isLoading) return;

              setDialogState(() {
                isLoading = true;
                statusMessage = 'Memproses izin notifikasi...';
              });

              try {
                final granted = await NotificationService.instance
                    .requestPermission();

                if (!dialogContext.mounted) return;

                if (!granted) {
                  setDialogState(() {
                    isLoading = false;
                    statusMessage =
                        'Izin notifikasi belum diberikan. Periksa pengaturan perangkat.';
                  });
                  return;
                }

                setDialogState(() {
                  statusMessage = 'Mengambil token FCM...';
                });

                final token = await NotificationService.instance.getFcmToken();

                if (!dialogContext.mounted) return;

                setDialogState(() {
                  fcmToken = token;
                  isLoading = false;
                  statusMessage = token != null
                      ? 'Notifikasi berhasil diaktifkan!'
                      : 'Token belum tersedia. Silakan coba lagi.';
                });
              } catch (e) {
                debugPrint('FCM Error: $e');

                if (!dialogContext.mounted) return;

                setDialogState(() {
                  isLoading = false;
                  statusMessage = 'Gagal mengaktifkan notifikasi.';
                });
              }
            }

            Future<void> copyToken() async {
              if (fcmToken == null || fcmToken!.isEmpty) return;

              await Clipboard.setData(ClipboardData(text: fcmToken!));

              if (!dialogContext.mounted) return;

              setDialogState(() {
                statusMessage = 'Token berhasil disalin!';
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.notifications_active_rounded,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Pengaturan Notifikasi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: AppTheme.softBlue,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.notifications_rounded,
                            color: AppTheme.primary,
                            size: 30,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Firebase Cloud Messaging',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.navy,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Aktifkan notifikasi untuk menerima pesan dari UniFlow.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Status Notifikasi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      statusMessage,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.grey,
                      ),
                    ),
                    if (isLoading) ...[
                      const SizedBox(height: 15),
                      const Center(child: CircularProgressIndicator()),
                    ],
                    if (fcmToken != null) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'FCM Registration Token',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.navy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: SelectableText(
                          fcmToken!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.navy,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: copyToken,
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Salin Token'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Tutup'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : activateFCM,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    fcmToken == null
                        ? 'Aktifkan & Ambil Token'
                        : 'Perbarui Token',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // EDIT NAME
  // ============================================================

  Future<void> editName(String currentName) async {
    if (isUpdatingName || !mounted) return;

    final controller = TextEditingController(text: currentName);

    try {
      final newName = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Edit Nama'),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama Lengkap',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              onSubmitted: (value) {
                final name = value.trim();

                if (name.isNotEmpty) {
                  Navigator.pop(dialogContext, name);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final name = controller.text.trim();

                  if (name.isEmpty) return;

                  Navigator.pop(dialogContext, name);
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      );

      if (newName == null || newName.isEmpty || !mounted) return;

      final user = auth.currentUser;

      if (user == null) {
        showMessage('Silakan login kembali.');
        return;
      }

      setState(() {
        isUpdatingName = true;
      });

      try {
        await user.updateDisplayName(newName);

        await firestoreService.saveUser(name: newName, email: user.email ?? '');

        if (!mounted) return;

        refreshProfile();
        showMessage('Nama berhasil diperbarui!');
      } catch (e) {
        debugPrint('Gagal memperbarui nama: $e');
        showMessage('Gagal memperbarui nama. Silakan coba lagi.');
      } finally {
        if (mounted) {
          setState(() {
            isUpdatingName = false;
          });
        }
      }
    } finally {
      controller.dispose();
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    if (isLoggingOut || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Logout'),
          content: const Text(
            'Apakah kamu yakin ingin keluar dari akun UniFlow?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    setState(() {
      isLoggingOut = true;
    });

    try {
      await auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomePage()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Gagal logout: $e');

      showMessage('Gagal logout. Silakan coba lagi.');

      if (mounted) {
        setState(() {
          isLoggingOut = false;
        });
      }
    }
  }

  // ============================================================
  // FIRESTORE STATISTICS
  // ============================================================

  Widget firestoreStatistic({
    required IconData icon,
    required String title,
    required Stream<QuerySnapshot<Map<String, dynamic>>> stream,
    required Color color,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        String value = '...';

        if (snapshot.hasData) {
          value = snapshot.data!.docs.length.toString();
        } else if (snapshot.hasError) {
          value = '-';
        }

        return statisticCard(
          icon: icon,
          title: title,
          value: value,
          color: color,
        );
      },
    );
  }

  Widget statisticCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 27),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: AppTheme.navy,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: const TextStyle(color: AppTheme.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget settingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.navy,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.grey),
      onTap: onTap,
    );
  }

  // ============================================================
  // PROFILE UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Profile',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Manage your personal information.',
                style: TextStyle(color: AppTheme.grey),
              ),
              const SizedBox(height: 25),

              // PROFILE HEADER
              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: userFuture,
                builder: (context, snapshot) {
                  final data = snapshot.data?.data();

                  final name =
                      data?['name'] ?? user?.displayName ?? 'Student Name';

                  final email = user?.email ?? 'Email tidak tersedia';

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: AppTheme.blueGradient(),
                    child: Column(
                      children: [
                        Builder(
                          builder: (context) {
                            final photoBase64 = data?['photoBase64'] as String?;
                            ImageProvider? profileImage;

                            if (photoBase64 != null && photoBase64.isNotEmpty) {
                              try {
                                profileImage = MemoryImage(
                                  base64Decode(photoBase64),
                                );
                              } catch (e) {
                                debugPrint('Data foto profil tidak valid: $e');
                              }
                            }

                            return Column(
                              children: [
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.10,
                                            ),
                                            blurRadius: 15,
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 48,
                                        backgroundColor: AppTheme.softBlue,
                                        backgroundImage: profileImage,
                                        child: profileImage == null
                                            ? const Icon(
                                                Icons.person_rounded,
                                                size: 55,
                                                color: AppTheme.primary,
                                              )
                                            : null,
                                      ),
                                    ),
                                    Material(
                                      color: AppTheme.primary,
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: isUpdatingPhoto
                                            ? null
                                            : pickAndSaveProfilePhoto,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: isUpdatingPhoto
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.camera_alt_rounded,
                                                  size: 17,
                                                  color: Colors.white,
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                TextButton.icon(
                                  onPressed: isUpdatingPhoto
                                      ? null
                                      : pickAndSaveProfilePhoto,
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    isUpdatingPhoto
                                        ? 'Menyimpan...'
                                        : 'Ubah Foto',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                if (profileImage != null)
                                  TextButton.icon(
                                    onPressed: isUpdatingPhoto
                                        ? null
                                        : deleteProfilePhoto,
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Hapus Foto',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          email,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'UniFlow Member ✨',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextButton.icon(
                          onPressed: isUpdatingName
                              ? null
                              : () => editName(name.toString()),
                          icon: isUpdatingName
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.edit_rounded,
                                  color: Colors.white,
                                  size: 17,
                                ),
                          label: Text(
                            isUpdatingName ? 'Menyimpan...' : 'Edit Name',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 25),

              // STATISTICS
              const Text(
                'My Statistics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 13),

              Row(
                children: [
                  Expanded(
                    child: firestoreStatistic(
                      icon: Icons.task_alt_rounded,
                      title: 'Tasks',
                      stream: tasksStream,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: statisticCard(
                      icon: Icons.timer_rounded,
                      title: 'Focus Hours',
                      value: '-',
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: firestoreStatistic(
                      icon: Icons.sticky_note_2_rounded,
                      title: 'Notes',
                      stream: notesStream,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: firestoreStatistic(
                      icon: Icons.calendar_month_rounded,
                      title: "Today's Routines",
                      stream: routinesStream,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // ACCOUNT SETTINGS
              const Text(
                'Account Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                decoration: AppTheme.cardDecoration(),
                child: Column(
                  children: [
                    settingItem(
                      icon: Icons.person_outline_rounded,
                      title: 'Personal Information',
                      onTap: () async {
                        try {
                          final profile = await firestoreService.getUser();

                          if (!mounted) return;

                          final name =
                              profile.data()?['name'] ??
                              auth.currentUser?.displayName ??
                              'Student Name';

                          await editName(name.toString());
                        } catch (e) {
                          debugPrint('Gagal mengambil profil: $e');
                          showMessage('Gagal mengambil profil.');
                        }
                      },
                    ),
                    const Divider(height: 1),
                    settingItem(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      onTap: openNotificationSettings,
                    ),
                    const Divider(height: 1),
                    settingItem(
                      icon: Icons.lock_outline_rounded,
                      title: 'Privacy & Security',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PrivacySecurityPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    settingItem(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & Support',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HelpSupportPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // LOGOUT
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: isLoggingOut ? null : logout,
                  icon: isLoggingOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.red,
                          ),
                        )
                      : const Icon(Icons.logout_rounded, color: Colors.red),
                  label: Text(
                    isLoggingOut ? 'Logging out...' : 'Logout',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Center(
                child: Text(
                  'UniFlow v1.0.0',
                  style: TextStyle(color: AppTheme.grey, fontSize: 12),
                ),
              ),

              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PRIVACY & SECURITY PAGE
// ============================================================

class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  final FirebaseAuth auth = FirebaseAuth.instance;

  bool isChangingPassword = false;

  User? get currentUser => auth.currentUser;

  bool get canChangePassword {
    return currentUser?.providerData.any(
          (provider) => provider.providerId == 'password',
        ) ??
        false;
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.primary),
    );
  }

  // CHANGE PASSWORD
  Future<void> changePassword() async {
    if (isChangingPassword) return;

    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Ubah Password',
              style: TextStyle(
                color: AppTheme.navy,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password Saat Ini',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: newController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password Baru',
                      prefixIcon: Icon(Icons.lock_reset_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Konfirmasi Password Baru',
                      prefixIcon: Icon(Icons.verified_user_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Password baru minimal 6 karakter.',
                    style: TextStyle(fontSize: 12, color: AppTheme.grey),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      );

      if (result != true || !mounted) return;

      final currentPassword = currentController.text;
      final newPassword = newController.text;
      final confirmPassword = confirmController.text;

      if (currentPassword.isEmpty ||
          newPassword.isEmpty ||
          confirmPassword.isEmpty) {
        showMessage('Semua kolom harus diisi.');
        return;
      }

      if (newPassword.length < 6) {
        showMessage('Password baru minimal 6 karakter.');
        return;
      }

      if (newPassword != confirmPassword) {
        showMessage('Konfirmasi password tidak cocok.');
        return;
      }

      if (currentPassword == newPassword) {
        showMessage('Password baru harus berbeda.');
        return;
      }

      final user = currentUser;
      final email = user?.email;

      if (user == null || email == null) {
        showMessage('Akun tidak ditemukan. Silakan login kembali.');
        return;
      }

      setState(() {
        isChangingPassword = true;
      });

      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      if (!mounted) return;

      showMessage('Password berhasil diperbarui!');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        showMessage('Password saat ini tidak sesuai.');
      } else if (e.code == 'weak-password') {
        showMessage('Password baru terlalu lemah.');
      } else if (e.code == 'requires-recent-login') {
        showMessage('Silakan login ulang sebelum mengganti password.');
      } else {
        showMessage('Gagal mengubah password: ${e.message ?? e.code}');
      }
    } catch (e) {
      debugPrint('Change password error: $e');
      showMessage('Terjadi kesalahan saat mengubah password.');
    } finally {
      currentController.dispose();
      newController.dispose();
      confirmController.dispose();

      if (mounted) {
        setState(() {
          isChangingPassword = false;
        });
      }
    }
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: AppTheme.navy,
        ),
      ),
    );
  }

  Widget infoCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.softBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navy,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.grey,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = currentUser;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.navy),
        title: const Text(
          'Privacy & Security',
          style: TextStyle(color: AppTheme.navy, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: AppTheme.blueGradient(),
                child: const Column(
                  children: [
                    Icon(Icons.shield_rounded, color: Colors.white, size: 55),
                    SizedBox(height: 12),
                    Text(
                      'Your Privacy Matters',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'UniFlow membantu menjaga informasi akun dan aktivitas belajar kamu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              sectionTitle('Privacy'),

              infoCard(
                icon: Icons.storage_rounded,
                title: 'Penyimpanan Data',
                description:
                    'Informasi akun dan data aplikasi seperti tugas, catatan, serta rutinitas disimpan menggunakan layanan Firebase.',
              ),

              infoCard(
                icon: Icons.person_outline_rounded,
                title: 'Informasi Pribadi',
                description:
                    'Informasi profil yang digunakan aplikasi meliputi nama dan alamat email akun.',
              ),

              infoCard(
                icon: Icons.notifications_active_outlined,
                title: 'Data Notifikasi',
                description:
                    'UniFlow menggunakan Firebase Cloud Messaging untuk mendukung pengiriman notifikasi aplikasi.',
              ),

              infoCard(
                icon: Icons.privacy_tip_outlined,
                title: 'Penggunaan Data',
                description:
                    'Data digunakan untuk mendukung fitur akun, pengelolaan tugas, catatan, rutinitas, dan notifikasi UniFlow.',
              ),

              sectionTitle('Account Information'),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(17),
                decoration: AppTheme.cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Email Akun',
                      style: TextStyle(color: AppTheme.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user?.email ?? 'Email tidak tersedia',
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Divider(height: 25),
                    const Text(
                      'Status Akun',
                      style: TextStyle(color: AppTheme.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          color: Colors.green,
                          size: 18,
                        ),
                        SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Terhubung dengan Firebase Authentication',
                            style: TextStyle(
                              color: AppTheme.navy,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              sectionTitle('Security'),

              infoCard(
                icon: Icons.lock_outline_rounded,
                title: 'Keamanan Akun',
                description:
                    'Akun UniFlow menggunakan Firebase Authentication untuk proses autentikasi pengguna.',
              ),

              if (canChangePassword)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.cardDecoration(),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.password_rounded,
                        color: AppTheme.primary,
                        size: 27,
                      ),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ubah Password',
                              style: TextStyle(
                                color: AppTheme.navy,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Perbarui password akun kamu.',
                              style: TextStyle(
                                color: AppTheme.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: isChangingPassword ? null : changePassword,
                        icon: isChangingPassword
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 18,
                                color: AppTheme.primary,
                              ),
                      ),
                    ],
                  ),
                )
              else
                infoCard(
                  icon: Icons.info_outline_rounded,
                  title: 'Metode Login',
                  description:
                      'Akun ini tidak menggunakan metode email dan password. Pengaturan password dilakukan melalui penyedia login yang digunakan.',
                ),

              const SizedBox(height: 25),

              const Center(
                child: Text(
                  'UniFlow • Privacy & Security • v1.0.0',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.grey, fontSize: 11),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HELP & SUPPORT PAGE
// ============================================================

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  final TextEditingController problemController = TextEditingController();

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.primary),
    );
  }

  // REPORT PROBLEM
  Future<void> reportProblem() async {
    problemController.clear();

    final message = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Laporkan Kendala',
            style: TextStyle(color: AppTheme.navy, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: problemController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Ceritakan kendala yang kamu alami...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final value = problemController.text.trim();

                if (value.isEmpty) return;

                Navigator.pop(dialogContext, value);
              },
              child: const Text('Salin Laporan'),
            ),
          ],
        );
      },
    );

    if (message == null || message.isEmpty || !mounted) return;

    final report =
        '''
LAPORAN KENDALA UNIFLOW

Email: ${FirebaseAuth.instance.currentUser?.email ?? 'Tidak tersedia'}

Kendala:
$message

Versi aplikasi: UniFlow v1.0.0
''';

    await Clipboard.setData(ClipboardData(text: report));

    if (!mounted) return;

    showMessage(
      'Laporan berhasil disalin. Kamu bisa mengirimkannya kepada pengembang.',
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: AppTheme.navy,
        ),
      ),
    );
  }

  Widget helpCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.softBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.grey,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget faqItem({required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.cardDecoration(),
      child: ExpansionTile(
        iconColor: AppTheme.primary,
        collapsedIconColor: AppTheme.grey,
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.navy,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              answer,
              style: const TextStyle(
                color: AppTheme.grey,
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    problemController.dispose();
    super.dispose();
  }

  // ============================================================
  // HELP & SUPPORT UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.navy),
        title: const Text(
          'Help & Support',
          style: TextStyle(color: AppTheme.navy, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(23),
                decoration: AppTheme.blueGradient(),
                child: const Column(
                  children: [
                    Icon(
                      Icons.support_agent_rounded,
                      color: Colors.white,
                      size: 55,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'How Can We Help You?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Temukan panduan dan solusi untuk menggunakan UniFlow.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              sectionTitle('Panduan Penggunaan'),

              helpCard(
                icon: Icons.task_alt_rounded,
                title: 'Task Management',
                description:
                    'Tambahkan tugas, isi deskripsi, tentukan prioritas, dan atur deadline. Kamu juga dapat mengedit, menghapus, serta menandai tugas yang telah selesai.',
              ),

              helpCard(
                icon: Icons.sticky_note_2_rounded,
                title: 'Notes',
                description:
                    'Buat catatan untuk menyimpan informasi penting. Gunakan kategori Lecture, Assignment, Exam, dan Personal.',
              ),

              helpCard(
                icon: Icons.timer_rounded,
                title: 'Focus Mode',
                description:
                    'Gunakan Focus Mode untuk membantu mengatur waktu belajar. Atur durasi fokus dan manfaatkan timer.',
              ),

              helpCard(
                icon: Icons.calendar_month_rounded,
                title: 'Daily Routines',
                description:
                    'Tambahkan rutinitas harian untuk membantu mengatur aktivitas dan kebiasaan belajar.',
              ),

              helpCard(
                icon: Icons.notifications_active_rounded,
                title: 'Notifications',
                description:
                    'Aktifkan izin notifikasi pada perangkat agar UniFlow dapat memberikan pemberitahuan sesuai fitur yang tersedia.',
              ),

              sectionTitle('Frequently Asked Questions'),

              faqItem(
                question: 'Bagaimana cara mengubah nama profil?',
                answer:
                    'Buka halaman Profile, pilih Edit Name atau Personal Information, kemudian masukkan nama baru dan tekan Simpan.',
              ),

              faqItem(
                question: 'Bagaimana cara mengubah password?',
                answer:
                    'Buka Profile, pilih Privacy & Security, lalu pilih Ubah Password. Masukkan password saat ini dan password baru. Fitur ini tersedia untuk akun email dan password.',
              ),

              faqItem(
                question: 'Mengapa notifikasi tidak muncul?',
                answer:
                    'Pastikan izin notifikasi UniFlow sudah diberikan melalui pengaturan perangkat. Periksa juga koneksi internet dan pengaturan notifikasi aplikasi.',
              ),

              faqItem(
                question: 'Apakah data tugas dan catatan tersimpan?',
                answer:
                    'Data tugas dan catatan disimpan menggunakan Firebase Firestore sehingga dapat diakses kembali melalui akun yang digunakan.',
              ),

              faqItem(
                question: 'Bagaimana cara keluar dari akun?',
                answer:
                    'Buka halaman Profile, kemudian tekan tombol Logout dan konfirmasi untuk keluar dari akun UniFlow.',
              ),

              sectionTitle('Contact & Support'),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: AppTheme.cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.support_agent_rounded,
                          color: AppTheme.primary,
                          size: 28,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Butuh Bantuan?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.navy,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      'Jika mengalami masalah saat menggunakan UniFlow, tuliskan kendala yang kamu alami. Laporan dapat disalin untuk dikirimkan kepada pengembang aplikasi.',
                      style: TextStyle(
                        color: AppTheme.grey,
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: reportProblem,
                        icon: const Icon(Icons.report_problem_outlined),
                        label: const Text('Laporkan Kendala'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              const Center(
                child: Text(
                  'UniFlow v1.0.0',
                  style: TextStyle(color: AppTheme.grey, fontSize: 12),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
