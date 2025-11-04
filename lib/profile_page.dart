import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_wrapper.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _dailyNotificationEnabled = false;
  bool _emergencyAlertEnabled = false;

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
  // --- Akhir Fungsi Logout ---

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
  // --- Akhir Fungsi Hapus Akun ---

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF3B82F6);
    const Color dangerRed = Colors.redAccent;

    // Ambil user terbaru SETIAP KALI BUILD
    // Ini penting agar nama bisa di-refresh setelah diedit
    final User? currentUser = FirebaseAuth.instance.currentUser;

    final String userName =
        currentUser?.displayName ?? "Pengguna"; // <-- Jauh lebih bersih
    final String userEmail = currentUser?.email ?? "email@example.com";

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
                  userName, // <-- Nama akan ter-refresh di sini
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
                  // --- UBAH FUNGSI ONTAP INI ---
                  onTap: () async {
                    // Navigasi ke EditProfilePage dan tunggu hasilnya
                    final bool? profileUpdated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditProfilePage(),
                      ),
                    );

                    // Jika hasilnya 'true' (berarti update berhasil),
                    // panggil setState untuk me-refresh UI halaman ini
                    if (profileUpdated == true) {
                      setState(() {
                        // Tidak perlu melakukan apa-apa di sini,
                        // build() akan otomatis dipanggil ulang
                        // dan mengambil data currentUser yang baru.
                      });
                    }
                  },
                  // --- AKHIR PERUBAHAN ONTAP ---
                ),
                _buildDivider(),
                _buildSwitchOptionRow(
                  icon: Icons.notifications_none_outlined,
                  text: 'Daily Notification',
                  value: _dailyNotificationEnabled,
                  onChanged: (value) {
                    setState(() {
                      _dailyNotificationEnabled = value;
                    });
                  },
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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
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
