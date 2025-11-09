import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart'; // <-- IMPORT BARU
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

  // --- Fungsi Memuat Pengaturan (Tidak Berubah) ---
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

  // --- Fungsi Menyimpan Pengaturan (Tidak Berubah) ---
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

  // --- Fungsi Logout (Tidak Berubah) ---
  Future<void> _handleLogout() async {
    // ... (Kode Logout Anda)
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

  // --- Fungsi Hapus Akun (Tidak Berubah) ---
  Future<void> _handleDeleteAccount() async {
    // ... (Kode Hapus Akun Anda)
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

  // --- FUNGSI NOTIFIKASI YANG DIPERBARUI ---
  Future<void> _handleDailyNotificationChange(bool newValue) async {
    final notificationService = NotificationService();

    if (newValue == true) {
      // --- PENGGUNA MENCOBA MENGAKTIFKAN ---

      // 1. Cek Izin Alarm
      final PermissionStatus status =
          await Permission.scheduleExactAlarm.status;

      if (!status.isGranted) {
        // 2. Jika izin belum ada, tampilkan dialog penjelasan
        if (mounted) {
          await _showAlarmPermissionDialog();
        }
        // Berhenti di sini. Toggle akan otomatis kembali ke 'off'
        // karena kita tidak memanggil setState(true)
        return;
      }

      // 3. Jika izin SUDAH ADA, lanjutkan ke TimePicker
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime:
            _selectedNotificationTime ?? const TimeOfDay(hour: 8, minute: 0),
        helpText: 'Pilih Waktu Notifikasi Harian',
        cancelText: 'Batal',
        confirmText: 'Pilih',
      );

      if (pickedTime != null) {
        // --- Pengguna memilih waktu (tidak cancel) ---
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
      } else {
        // --- Pengguna menekan 'Batal' di time picker ---
      }
    } else {
      // --- PENGGUNA MENONAKTIFKAN toggle ---
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
  // --- AKHIR FUNGSI NOTIFIKASI ---

  // --- FUNGSI BARU: Dialog Izin Alarm ---
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
                openAppSettings(); // <-- Buka pengaturan aplikasi
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  // --- AKHIR FUNGSI BARU ---

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

  // --- Helper Widgets (Tidak berubah) ---

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
