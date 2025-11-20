// lib/profile_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'auth_wrapper.dart';
import 'edit_profile_page.dart';
import 'notification_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Kunci untuk SharedPreferences
  static const String _kNotificationEnabledKey = 'daily_notification_enabled';
  static const String _kNotificationTimeHourKey = 'daily_notification_hour';
  static const String _kNotificationTimeMinuteKey = 'daily_notification_minute';

  bool _dailyNotificationEnabled = false;
  TimeOfDay? _selectedNotificationTime;
  bool _emergencyAlertEnabled = false;
  bool _isLoadingSettings = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // --- Fungsi Memuat Pengaturan ---
  Future<void> _loadSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _dailyNotificationEnabled =
          prefs.getBool(_kNotificationEnabledKey) ?? false;
      final int? hour = prefs.getInt(_kNotificationTimeHourKey);
      final int? minute = prefs.getInt(_kNotificationTimeMinuteKey);

      if (hour != null && minute != null) {
        _selectedNotificationTime = TimeOfDay(hour: hour, minute: minute);
      } else {
        _selectedNotificationTime = null;
      }
      _isLoadingSettings = false;
    });
  }

  // --- Fungsi Menyimpan Pengaturan ---
  Future<void> _saveSettings(bool enabled, TimeOfDay? time) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotificationEnabledKey, enabled);
    if (time != null) {
      await prefs.setInt(_kNotificationTimeHourKey, time.hour);
      await prefs.setInt(_kNotificationTimeMinuteKey, time.minute);
    } else {
      await prefs.remove(_kNotificationTimeHourKey);
      await prefs.remove(_kNotificationTimeMinuteKey);
    }
  }

  // --- FITUR BARU: GANTI PASSWORD (PERMANTAP UI) ---
  Future<void> _showChangePasswordDialog() async {
    final TextEditingController oldPassController = TextEditingController();
    final TextEditingController newPassController = TextEditingController();
    final TextEditingController confirmPassController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    // Variabel state lokal
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isLoading = false;

    // Warna Tema
    const Color primaryBlue = Color(0xFF3B82F6);
    const Color lightBlueBg = Color(0xFFEFF6FF);

    // Helper untuk Input Decoration yang Rapi
    InputDecoration _buildInputDecoration(
      String label,
      IconData icon,
      bool isObscure,
      VoidCallback onToggle,
    ) {
      return InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
        filled: true,
        fillColor: Colors.grey[50], // Background input sangat muda
        prefixIcon: Icon(icon, color: primaryBlue.withOpacity(0.7), size: 22),
        suffixIcon: IconButton(
          icon: Icon(
            isObscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: Colors.grey[400],
            size: 20,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none, // Hilangkan border default agar clean
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      );
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. Header Icon
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: lightBlueBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_reset_rounded,
                            color: primaryBlue,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 2. Title
                        const Text(
                          'Ganti Password',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Masukkan password lama dan baru Anda.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 24),

                        // 3. Form Inputs
                        TextFormField(
                          controller: oldPassController,
                          obscureText: obscureOld,
                          decoration: _buildInputDecoration(
                            'Password Lama',
                            Icons.lock_outline_rounded,
                            obscureOld,
                            () =>
                                setStateDialog(() => obscureOld = !obscureOld),
                          ),
                          validator: (val) =>
                              val!.isEmpty ? 'Password lama wajib diisi' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: newPassController,
                          obscureText: obscureNew,
                          decoration: _buildInputDecoration(
                            'Password Baru',
                            Icons.vpn_key_outlined,
                            obscureNew,
                            () =>
                                setStateDialog(() => obscureNew = !obscureNew),
                          ),
                          validator: (val) =>
                              val!.length < 6 ? 'Minimal 6 karakter' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: confirmPassController,
                          obscureText: obscureConfirm,
                          decoration: _buildInputDecoration(
                            'Ulangi Password Baru',
                            Icons.check_circle_outline_rounded,
                            obscureConfirm,
                            () => setStateDialog(
                              () => obscureConfirm = !obscureConfirm,
                            ),
                          ),
                          validator: (val) {
                            if (val != newPassController.text) {
                              return 'Password tidak sama';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 30),

                        // 4. Action Buttons
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () async {
                                    if (formKey.currentState!.validate()) {
                                      setStateDialog(() => isLoading = true);

                                      try {
                                        User? user =
                                            FirebaseAuth.instance.currentUser;
                                        String email = user?.email ?? '';

                                        // Re-autentikasi
                                        AuthCredential credential =
                                            EmailAuthProvider.credential(
                                              email: email,
                                              password: oldPassController.text,
                                            );

                                        await user
                                            ?.reauthenticateWithCredential(
                                              credential,
                                            );

                                        // Update Password
                                        await user?.updatePassword(
                                          newPassController.text,
                                        );

                                        if (mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Password berhasil diubah!',
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      } on FirebaseAuthException catch (e) {
                                        String errorMsg =
                                            'Gagal mengubah password.';
                                        if (e.code == 'wrong-password') {
                                          errorMsg = 'Password lama salah.';
                                        } else if (e.code == 'weak-password') {
                                          errorMsg =
                                              'Password baru terlalu lemah.';
                                        }
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(errorMsg),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      } finally {
                                        if (mounted &&
                                            Navigator.canPop(context)) {
                                          setStateDialog(
                                            () => isLoading = false,
                                          );
                                        }
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Simpan Password',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () => Navigator.pop(context),
                          child: Text(
                            'Batal',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
  // --- AKHIR FITUR GANTI PASSWORD ---

  // --- Fungsi Logout ---
  Future<void> _handleLogout() async {
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Logout'),
          content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmLogout == true) {
      try {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthWrapper()),
            (Route<dynamic> route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal logout: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // --- Fungsi Hapus Akun ---
  Future<void> _handleDeleteAccount() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Hapus Akun'),
          content: const Text(
            'Apakah Anda YAKIN ingin menghapus akun ini secara permanen? Semua data Anda (termasuk riwayat mood) akan hilang dan tidak dapat dikembalikan.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text(
                'HAPUS PERMANEN',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );
      }

      try {
        await user.delete();

        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthWrapper()),
            (Route<dynamic> route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Akun berhasil dihapus'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          Navigator.of(context).pop();
        }
        String message = 'Gagal menghapus akun.';

        if (e.code == 'requires-recent-login') {
          message =
              'Aksi ini memerlukan verifikasi. Harap logout dan login kembali sebelum mencoba menghapus akun.';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$message Kode: ${e.code}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Terjadi kesalahan: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // --- Fungsi Notifikasi ---
  Future<void> _handleDailyNotificationChange(bool newValue) async {
    final notificationService = NotificationService();

    if (newValue == true) {
      final PermissionStatus status =
          await Permission.scheduleExactAlarm.status;

      if (!status.isGranted) {
        if (mounted) {
          await _showAlarmPermissionDialog();
        }
        return;
      }

      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime:
            _selectedNotificationTime ?? const TimeOfDay(hour: 8, minute: 0),
        helpText: 'Pilih Waktu Notifikasi Harian',
        cancelText: 'Batal',
        confirmText: 'Pilih',
      );

      if (pickedTime != null) {
        setState(() {
          _dailyNotificationEnabled = true;
          _selectedNotificationTime = pickedTime;
        });

        await notificationService.scheduleDailyNotification(pickedTime);
        await _saveSettings(true, pickedTime);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Notifikasi harian diatur untuk ${pickedTime.format(context)}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } else {
      setState(() {
        _dailyNotificationEnabled = false;
        _selectedNotificationTime = null;
      });

      await notificationService.cancelAllNotifications();
      await _saveSettings(false, null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifikasi harian dinonaktifkan.'),
            backgroundColor: Colors.grey,
          ),
        );
      }
    }
  }

  // --- Dialog Izin Alarm ---
  Future<void> _showAlarmPermissionDialog() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Izin Diperlukan'),
          content: const Text(
            'Untuk memastikan notifikasi harian dapat muncul tepat waktu, MoodWise memerlukan izin "Alarm & Pengingat".\n\nKetuk "Buka Pengaturan" untuk mengaktifkannya.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Buka Pengaturan'),
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF3B82F6);
    const Color dangerRed = Colors.redAccent;

    final User? currentUser = FirebaseAuth.instance.currentUser;

    final String userName = currentUser?.displayName ?? "Pengguna";
    final String userEmail = currentUser?.email ?? "email@example.com";

    final String? notificationTimeText =
        (_dailyNotificationEnabled && _selectedNotificationTime != null)
        ? 'Diatur untuk: ${_selectedNotificationTime!.format(context)}'
        : null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
          children: [
            // Bagian Atas
            Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: primaryBlue.withOpacity(0.15),
                  child: Icon(
                    Icons.person,
                    size: 60,
                    color: primaryBlue.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  userEmail,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 40),
            // Section Pengaturan
            _buildSectionTitle('Pengaturan'),
            const SizedBox(height: 10),
            _buildSettingsCard(
              children: [
                _buildProfileOptionRow(
                  icon: Icons.edit_outlined,
                  text: 'Edit Profile',
                  onTap: () async {
                    final bool? profileUpdated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditProfilePage(),
                      ),
                    );

                    if (profileUpdated == true) {
                      setState(() {
                        // Build akan dipanggil ulang
                      });
                    }
                  },
                ),
                _buildDivider(),
                // Tampilkan loading atau switch
                _isLoadingSettings
                    ? const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 15.0,
                          vertical: 28.0,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.notifications_none_outlined,
                              color: Colors.black54,
                            ),
                            SizedBox(width: 15),
                            Expanded(
                              child: Text(
                                'Memuat pengaturan notifikasi...',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildSwitchOptionRow(
                        icon: Icons.notifications_none_outlined,
                        text: 'Daily Notification',
                        value: _dailyNotificationEnabled,
                        onChanged: _handleDailyNotificationChange,
                        subtitle: notificationTimeText,
                      ),
                _buildDivider(),
                _buildSwitchOptionRow(
                  icon: Icons.warning_amber_rounded,
                  text: 'Emergency Alert',
                  value: _emergencyAlertEnabled,
                  onChanged: (value) {
                    setState(() {
                      _emergencyAlertEnabled = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 30),
            // Section Akun
            _buildSectionTitle('Akun'),
            const SizedBox(height: 10),
            _buildSettingsCard(
              children: [
                // --- MENU GANTI PASSWORD ---
                _buildProfileOptionRow(
                  icon: Icons.lock_outline, // Menggunakan ikon gembok biasa
                  text: 'Change Password',
                  onTap:
                      _showChangePasswordDialog, // Panggil dialog ganti password
                ),
                _buildDivider(),
                // ---------------------------
                _buildProfileOptionRow(
                  icon: Icons.delete_outline,
                  text: 'Delete Account',
                  textColor: dangerRed,
                  iconColor: dangerRed,
                  onTap: _handleDeleteAccount,
                ),
                _buildDivider(),
                _buildProfileOptionRow(
                  icon: Icons.logout,
                  text: 'Logout',
                  textColor: dangerRed,
                  iconColor: dangerRed,
                  showArrow: false,
                  onTap: _handleLogout,
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 5.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF3B82F6),
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    const Color lightCardBg = Color(0xFFF0F9FF);
    const Color lightBorderBlue = Color(0xFFE0F2FE);
    return Container(
      decoration: BoxDecoration(
        color: lightCardBg,
        borderRadius: BorderRadius.circular(15.0),
        border: Border.all(color: lightBorderBlue, width: 1.0),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildProfileOptionRow({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    Color textColor = Colors.black87,
    Color iconColor = Colors.black54,
    bool showArrow = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 18.0),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (showArrow)
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchOptionRow({
    required IconData icon,
    required String text,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color iconColor = Colors.black54,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFF3B82F6).withOpacity(0.5),
            activeThumbColor: const Color(0xFF3B82F6),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: const Color(0xFFE0F2FE),
      indent: 50,
      endIndent: 15,
    );
  }
}
