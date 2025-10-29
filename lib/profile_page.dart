// lib/profile_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_wrapper.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Nanti akan dihubungkan ke state/logic sebenarnya
  bool _dailyNotificationEnabled = false; // Contoh state awal
  bool _emergencyAlertEnabled = false; // Contoh state awal
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // --- Fungsi Logout ---
  Future<void> _handleLogout() async {
    // Tampilkan dialog konfirmasi (opsional tapi bagus)
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
                Navigator.of(context).pop(false); // Kirim false
              },
            ),
            TextButton(
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(true); // Kirim true
              },
            ),
          ],
        );
      },
    );

    // Jika user menekan tombol "Logout" di dialog
    if (confirmLogout == true) {
      try {
        await FirebaseAuth.instance.signOut();
        // Navigasi kembali ke AuthWrapper/LoginPage setelah logout
        // AuthWrapper akan otomatis mendeteksi perubahan state dan menampilkan LoginPage
        // Jadi, idealnya tidak perlu navigasi manual di sini jika root adalah AuthWrapper
        // Tapi jika perlu (misal struktur navigasi beda):
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const AuthWrapper(),
            ), // Arahkan ke AuthWrapper
            (Route<dynamic> route) => false, // Hapus semua route sebelumnya
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

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF3B82F6);
    const Color dangerRed = Colors.redAccent;

    // Ambil nama & email (contoh sederhana)
    final String userName =
        currentUser?.displayName ??
        currentUser?.email?.split('@').first ??
        "Pengguna";
    final String userEmail = currentUser?.email ?? "email@example.com";

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          // Gunakan ListView agar bisa scroll jika konten panjang
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
          children: [
            // Bagian Atas: Avatar, Nama, Email
            Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: primaryBlue.withOpacity(
                    0.15,
                  ), // Background avatar
                  child: Icon(
                    Icons.person,
                    size: 60,
                    color: primaryBlue.withOpacity(0.8), // Warna ikon
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
            const SizedBox(height: 40), // Jarak ke section Pengaturan
            // Section Pengaturan
            _buildSectionTitle('Pengaturan'),
            const SizedBox(height: 10),
            _buildSettingsCard(
              children: [
                _buildProfileOptionRow(
                  icon: Icons.edit_outlined,
                  text: 'Edit Profile',
                  onTap: () {
                    print("Navigasi ke Edit Profile");
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Halaman Edit Profile nanti'),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                _buildSwitchOptionRow(
                  icon: Icons.notifications_none_outlined,
                  text: 'Daily Notification',
                  value: _dailyNotificationEnabled,
                  onChanged: (value) {
                    setState(() {
                      _dailyNotificationEnabled = value;
                      // Tambahkan logika simpan preferensi notifikasi nanti
                    });
                  },
                ),
                _buildDivider(), // Divider opsional antar switch
                _buildSwitchOptionRow(
                  icon: Icons.warning_amber_rounded,
                  text: 'Emergency Alert',
                  value: _emergencyAlertEnabled,
                  onChanged: (value) {
                    setState(() {
                      _emergencyAlertEnabled = value;
                      // Tambahkan logika simpan preferensi alert nanti
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 30), // Jarak ke section Akun
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
                  onTap: () {
                    print("Tampilkan dialog konfirmasi hapus akun");
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logika Hapus Akun nanti')),
                    );
                  },
                ),
                _buildDivider(),
                _buildProfileOptionRow(
                  icon: Icons.logout,
                  text: 'Logout',
                  textColor: dangerRed,
                  iconColor: dangerRed,
                  showArrow: false, // Logout tidak perlu panah navigasi
                  onTap: _handleLogout,
                ),
              ],
            ),
            const SizedBox(height: 30), // Padding bawah
          ],
        ),
      ),
    );
  }

  // Helper untuk judul section
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 5.0), // Sedikit indentasi
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF3B82F6), // Warna biru
        ),
      ),
    );
  }

  // Helper untuk card pembungkus
  Widget _buildSettingsCard({required List<Widget> children}) {
    const Color lightCardBg = Color(0xFFF0F9FF);
    const Color lightBorderBlue = Color(0xFFE0F2FE);
    return Container(
      decoration: BoxDecoration(
        color: lightCardBg, // Warna background card
        borderRadius: BorderRadius.circular(15.0),
        border: Border.all(color: lightBorderBlue, width: 1.0), // Border tipis
      ),
      child: Column(children: children),
    );
  }

  // Helper untuk baris opsi biasa (Edit, Delete, Logout)
  Widget _buildProfileOptionRow({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    Color textColor = Colors.black87,
    Color iconColor = Colors.black54,
    bool showArrow = true,
  }) {
    return InkWell(
      // Agar bisa diklik
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        15.0,
      ), // Agar ripple effect sesuai card
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

  // Helper untuk baris opsi dengan Switch
  Widget _buildSwitchOptionRow({
    required IconData icon,
    required String text,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color iconColor = Colors.black54,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 15.0,
        vertical: 8.0,
      ), // Padding vertikal lebih kecil
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
            activeColor: const Color(0xFF3B82F6), // Warna biru saat aktif
          ),
        ],
      ),
    );
  }

  // Helper untuk garis pemisah
  Widget _buildDivider() {
    return Divider(
      height: 1, // Tinggi divider
      thickness: 1, // Ketebalan garis
      color: const Color(0xFFE0F2FE), // Warna border card
      indent: 50, // Mulai setelah area ikon
      endIndent: 15,
    );
  }
}
