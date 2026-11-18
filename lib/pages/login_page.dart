import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'register_page.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool hidePassword = true;

  static const Color primaryBlue = Color(0xFF2874D0);
  static const Color darkBlue = Color(0xFF173B70);
  static const Color backgroundBlue = Color(0xFFF3F7FF);

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // LOGIN FIREBASE
  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('LOGIN FIREBASE ERROR: ${e.code}');
      debugPrint('LOGIN FIREBASE MESSAGE: ${e.message}');

      String message;

      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Email atau password salah.';
          break;

        case 'invalid-email':
          message = 'Format email tidak valid.';
          break;

        case 'user-disabled':
          message = 'Akun ini telah dinonaktifkan.';
          break;

        case 'too-many-requests':
          message = 'Terlalu banyak percobaan. Coba lagi nanti.';
          break;

        case 'network-request-failed':
          message =
              'Tidak dapat terhubung ke Firebase. Periksa koneksi internet kamu.';
          break;

        case 'operation-not-allowed':
          message = 'Login Email/Password belum diaktifkan di Firebase.';
          break;

        case 'invalid-api-key':
          message = 'Konfigurasi Firebase tidak valid.';
          break;

        default:
          message = 'Login gagal: ${e.message ?? e.code}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // LUPA PASSWORD
  Future<void> forgotPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan email terlebih dahulu.')),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link reset password telah dikirim ke email.'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'user-not-found':
          message = 'Email belum terdaftar.';
          break;

        case 'invalid-email':
          message = 'Format email tidak valid.';
          break;

        case 'network-request-failed':
          message = 'Periksa koneksi internet kamu.';
          break;

        default:
          message = e.message ?? 'Gagal mengirim email reset password.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // INPUT FIELD
  Widget inputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: darkBlue,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 9),

        TextFormField(
          controller: controller,
          obscureText: isPassword && hidePassword,
          keyboardType: isPassword
              ? TextInputType.text
              : TextInputType.emailAddress,
          validator: validator,
          style: const TextStyle(color: darkBlue, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9AA9BE), fontSize: 13),

            prefixIcon: Icon(icon, color: primaryBlue, size: 20),

            suffixIcon: isPassword
                ? IconButton(
                    onPressed: () {
                      setState(() {
                        hidePassword = !hidePassword;
                      });
                    },
                    icon: Icon(
                      hidePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xFF8295B0),
                      size: 20,
                    ),
                  )
                : null,

            filled: true,
            fillColor: Colors.white,

            contentPadding: const EdgeInsets.symmetric(
              horizontal: 17,
              vertical: 17,
            ),

            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Color(0xFFE1EAF7)),
            ),

            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Color(0xFFE1EAF7)),
            ),

            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: primaryBlue, width: 1.5),
            ),

            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),

            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundBlue,

      body: Stack(
        children: [
          // BACKGROUND
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEAF3FF), Color(0xFFF8FAFF), Colors.white],
              ),
            ),
          ),

          // LINGKARAN BACKGROUND ATAS
          Positioned(
            top: -80,
            right: -70,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                color: const Color(0xFFD9E9FF).withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // LINGKARAN BACKGROUND BAWAH
          Positioned(
            bottom: -90,
            left: -65,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                color: const Color(0xFFD9E9FF).withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // FORM LOGIN
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 27,
                  vertical: 25,
                ),

                child: Form(
                  key: _formKey,

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,

                    children: [
                      const SizedBox(height: 15),

                      // LOGO UNIFLOW
                      const Icon(
                        Icons.school_rounded,
                        size: 65,
                        color: primaryBlue,
                      ),

                      const SizedBox(height: 5),

                      const Text(
                        'UniFlow',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 29,
                          fontWeight: FontWeight.w900,
                          color: darkBlue,
                          letterSpacing: -0.8,
                        ),
                      ),

                      const SizedBox(height: 5),

                      const Text(
                        'Welcome Back!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: darkBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 35),

                      // EMAIL
                      inputField(
                        label: 'Email Address',
                        hint: 'Enter your email',
                        controller: emailController,
                        icon: Icons.email_outlined,

                        validator: (value) {
                          if (value == null ||
                              !RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(value.trim())) {
                            return 'Masukkan email yang valid';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // PASSWORD
                      inputField(
                        label: 'Password',
                        hint: 'Enter your password',
                        controller: passwordController,
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,

                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password wajib diisi';
                          }

                          return null;
                        },
                      ),

                      // FORGOT PASSWORD
                      Align(
                        alignment: Alignment.centerRight,

                        child: TextButton(
                          onPressed: forgotPassword,

                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: primaryBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // LOGIN BUTTON
                      SizedBox(
                        height: 51,

                        child: ElevatedButton(
                          onPressed: isLoading ? null : login,

                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,

                            disabledBackgroundColor: primaryBlue.withValues(
                              alpha: 0.6,
                            ),

                            elevation: 4,

                            shadowColor: primaryBlue.withValues(alpha: 0.25),

                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),

                          child: isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,

                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      // PEMISAH OR
                      const Row(
                        children: [
                          Expanded(child: Divider(color: Color(0xFFD7E2F1))),

                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 15),

                            child: Text(
                              'or',
                              style: TextStyle(
                                color: Color(0xFF8295B0),
                                fontSize: 12,
                              ),
                            ),
                          ),

                          Expanded(child: Divider(color: Color(0xFFD7E2F1))),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // CREATE ACCOUNT
                      SizedBox(
                        height: 49,

                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterPage(),
                              ),
                            );
                          },

                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryBlue,
                            backgroundColor: Colors.white,

                            side: const BorderSide(color: Color(0xFFD7E5F7)),

                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),

                          child: const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'Your Day, Your Flow.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF8295B0),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
