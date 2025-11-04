// lib/edit_profile_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _nameController.text = currentUser?.displayName ?? "";
    _emailController.text = currentUser?.email ?? "";
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User tidak ditemukan. Harap login ulang.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String newName = _nameController.text.trim();
    final String newEmail = _emailController.text.trim();
    final String oldName = user.displayName ?? "";
    final String oldEmail = user.email ?? "";

    final bool nameChanged = newName != oldName;
    final bool emailChanged = newEmail != oldEmail;

    if (!nameChanged && !emailChanged) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada perubahan'),
          backgroundColor: Colors.grey,
        ),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Kita perlu re-autentikasi (verifikasi password)
      final String? password = await _showPasswordDialog(
        isChangingEmail: emailChanged,
      );

      if (password == null || password.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return; // User batal
      }

      AuthCredential credential = EmailAuthProvider.credential(
        email: oldEmail,
        password: password,
      );

      // Lakukan re-autentikasi
      await user.reauthenticateWithCredential(credential);

      // --- LOGIKA UPDATE ---

      // 1. Logika Update Nama (jika berubah)
      if (nameChanged) {
        await user.updateDisplayName(newName);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'name': newName, // Sesuai register_page.dart
            });
      }

      // 2. Logika Update Email (jika berubah)
      String successMessage = 'Profile berhasil diperbarui';
      if (emailChanged) {
        // Gunakan metode yang diwajibkan oleh Identity Platform
        await user.verifyBeforeUpdateEmail(newEmail);

        // Sesuaikan pesan sukses
        successMessage =
            'Nama berhasil diperbarui. Sebuah link verifikasi telah dikirim ke $newEmail.';
        if (!nameChanged) {
          successMessage =
              'Sebuah link verifikasi telah dikirim ke $newEmail. Silakan cek email Anda.';
        }
      }
      // --- AKHIR LOGIKA UPDATE ---

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5), // Pesan lebih panjang
          ),
        );
        Navigator.of(context).pop(true); // Kirim 'true' = sukses
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Gagal memperbarui profile.';
      if (e.code == 'wrong-password') {
        message = 'Password yang Anda masukkan salah.';
      } else if (e.code == 'email-already-in-use') {
        message = 'Email baru tersebut sudah digunakan oleh akun lain.';
      } else if (e.code == 'invalid-email') {
        message = 'Format email baru tidak valid.';
      } else {
        message = 'Gagal: ${e.message}';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Dialog password (dengan pesan yang disesuaikan)
  Future<String?> _showPasswordDialog({required bool isChangingEmail}) async {
    final TextEditingController passwordDialogController =
        TextEditingController();
    final GlobalKey<FormState> dialogFormKey = GlobalKey<FormState>();

    String dialogMessage = isChangingEmail
        ? 'Untuk mengubah email, masukkan password Anda saat ini.'
        : 'Untuk menyimpan perubahan, masukkan password Anda saat ini.';

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Verifikasi Keamanan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(dialogMessage), // Pesan dinamis
              const SizedBox(height: 15),
              Form(
                key: dialogFormKey,
                child: TextFormField(
                  controller: passwordDialogController,
                  obscureText: true,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Password Anda',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.isEmpty
                      ? 'Password tidak boleh kosong'
                      : null,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (dialogFormKey.currentState!.validate()) {
                  Navigator.of(
                    context,
                  ).pop(passwordDialogController.text.trim());
                }
              },
              child: const Text('Konfirmasi'),
            ),
          ],
        );
      },
    );
  } // <-- INI ADALAH BRACE YANG HILANG (BARIS 236)

  @override
  Widget build(BuildContext context) {
    // UI (build widget) tidak perlu diubah
    const Color primaryBlue = Color(0xFF3B82F6);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'Nama Lengkap',
                    hintText: 'Masukkan nama lengkap Anda',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(
                        color: primaryBlue,
                        width: 2.0,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _emailController,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(
                        color: primaryBlue,
                        width: 2.0,
                      ),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || !value.contains('@')) {
                      return 'Masukkan email yang valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text(
                          'Simpan Perubahan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
