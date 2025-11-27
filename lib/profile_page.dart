// lib/profile_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
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

  // Persona state
  String _currentPersona = 'friendly';

  bool _dailyNotificationEnabled = false;
  TimeOfDay? _selectedNotificationTime;
  bool _emergencyAlertEnabled = false;
  bool _isLoadingSettings = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadPersona();
  }

  // Load persona dari Firestore
  Future<void> _loadPersona() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final savedPersona = doc.data()?['aiPersona'] as String?;
      if (savedPersona != null &&
          [
            'formal',
            'tough',
            'friendly',
            'coach',
            'motherly',
            'bestie',
          ].contains(savedPersona)) {
        setState(() => _currentPersona = savedPersona);
      }
      // Kalau null → tetap pakai 'friendly' sebagai default
    } catch (e) {
      debugPrint('Gagal load persona: $e');
      // Tetap pakai default 'friendly'
    }
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

  // Persona Selection Dialog
  Future<void> _showPersonaSelectionDialog() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pilih Persona AI'),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _personaTile('formal', 'Formal', 'Professional & Formal'),
            _personaTile('tough', 'Tough', 'Tegas & Disiplin (Tough Love)'),
            _personaTile('friendly', 'Friendly', 'Sahabat Ramah & Supportif'),
            _personaTile('coach', 'Coach', 'Motivator Energik'),
            _personaTile('motherly', 'Motherly', 'Keibuan & Mengayomi'),
            _personaTile('bestie', 'Bestie', 'Bestie Gaul Santai'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
        ],
      ),
    );

    if (selected != null && selected != _currentPersona) {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'aiPersona': selected,
      }, SetOptions(merge: true));

      setState(() => _currentPersona = selected);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Persona AI diubah jadi ${_getPersonaDisplayName(selected)}!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Widget _personaTile(String value, String title, String subtitle) {
    final isSelected = _currentPersona == value;
    return ListTile(
      leading: Radio<String>(
        value: value,
        groupValue: _currentPersona,
        onChanged: (val) => Navigator.pop(context, val),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
      selected: isSelected,
      selectedTileColor: Colors.blue.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () => Navigator.pop(context, value),
    );
  }

  // Nama tampilan persona
  String _getPersonaDisplayName(String key) {
    const map = {
      'formal': 'Formal',
      'tough': 'Tough',
      'friendly': 'Friendly',
      'coach': 'Coach',
      'motherly': 'Motherly',
      'bestie': 'Bestie',
    };
    return map[key] ?? 'Friendly';
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

    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? "Pengguna";
    final userEmail = user?.email ?? "email@example.com";

    final notificationTimeText =
        (_dailyNotificationEnabled && _selectedNotificationTime != null)
        ? 'Diatur untuk: ${_selectedNotificationTime!.format(context)}'
        : null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          children: [
            // Header
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

            // Pengaturan
            _buildSectionTitle('Pengaturan'),
            const SizedBox(height: 10),
            _buildSettingsCard(
              children: [
                _buildProfileOptionRow(
                  icon: Icons.smart_toy_outlined,
                  text: 'Persona AI',
                  subtitle:
                      'Saat ini: ${_getPersonaDisplayName(_currentPersona)}',
                  onTap: _showPersonaSelectionDialog,
                ),
                _buildDivider(),
                _buildProfileOptionRow(
                  icon: Icons.edit_outlined,
                  text: 'Edit Profile',
                  onTap: () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfilePage(),
                      ),
                    );
                    if (updated == true) setState(() {});
                  },
                ),
                _buildDivider(),
                _isLoadingSettings
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Memuat pengaturan...'),
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
                  onChanged: (v) => setState(() => _emergencyAlertEnabled = v),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Akun
            _buildSectionTitle('Akun'),
            const SizedBox(height: 10),
            _buildSettingsCard(
              children: [
                _buildProfileOptionRow(
                  icon: Icons.lock_outline,
                  text: 'Change Password',
                  onTap: _showChangePasswordDialog,
                ),
                _buildDivider(),
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

  // Helper Widgets (sama seperti sebelumnya)
  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(left: 5),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF3B82F6),
      ),
    ),
  );

  Widget _buildSettingsCard({required List<Widget> children}) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F9FF),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFE0F2FE)),
    ),
    child: Column(children: children),
  );

  Widget _buildProfileOptionRow({
    required IconData icon,
    required String text,
    String? subtitle,
    required VoidCallback onTap,
    Color textColor = Colors.black87,
    Color iconColor = Colors.black54,
    bool showArrow = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 18),
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
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitle,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ),
                ],
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
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color iconColor = Colors.black54,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
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
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF3B82F6),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => const Divider(
    height: 1,
    thickness: 1,
    color: Color(0xFFE0F2FE),
    indent: 50,
    endIndent: 15,
  );
}
