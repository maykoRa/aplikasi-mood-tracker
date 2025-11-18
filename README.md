# MoodWise: Aplikasi Mood Tracker


**MoodWise** adalah aplikasi pelacak suasana hati (mood tracker) lintas platform yang dibangun menggunakan Flutter. Aplikasi ini dirancang untuk membantu pengguna mencatat, memantau, dan menganalisis kesejahteraan emosional mereka dari waktu ke waktu.

Aplikasi ini tidak hanya berfungsi sebagai jurnal digital, tetapi juga dilengkapi dengan fitur-fitur berbasis AI untuk memberikan wawasan dan dukungan kepada pengguna.

---

## 🚀 Fitur Utama

Berdasarkan file-file di dalam direktori `lib/`, berikut adalah fitur-fitur utama aplikasi:

* 🔐 **Autentikasi Pengguna:** Sistem login dan registrasi yang aman menggunakan Firebase Authentication.
* ✍️ **Jurnal Mood Harian:** Pengguna dapat menambahkan entri baru (`add_entry_page.dart`), memperbarui, dan melihat detail entri (`entry_detail_page.dart`).
* 🗓️ **Riwayat Jurnal:** Menampilkan semua entri suasana hati yang pernah dicatat dalam tampilan riwayat yang terorganisir (`history_page.dart`).
* 📊 **Statistik Mood:** Visualisasi data suasana hati pengguna dalam bentuk statistik atau grafik untuk melihat tren dari waktu ke waktu (`statistics_page.dart`).
* 🤖 **AI Chatbot:** Fitur chatbot interaktif untuk membantu pengguna atau sekadar menjadi teman bicara (`chatbot_page.dart`).
* 💡 **Refleksi Berbasis AI:** Menggunakan AI (kemungkinan besar Gemini API melalui Firebase Functions) untuk menghasilkan refleksi atau rangkuman berdasarkan entri jurnal pengguna (`reflection_page.dart`).
* 👤 **Manajemen Profil:** Pengguna dapat melihat dan mengedit profil mereka (`profile_page.dart`, `edit_profile_page.dart`).

---

## 💻 Tumpukan Teknologi (Tech Stack)

Proyek ini menggunakan kombinasi teknologi frontend dan backend modern:

* **Frontend:**
    * [Flutter](https://flutter.dev/): Framework UI dari Google untuk membangun aplikasi mobile, web, dan desktop dari satu basis kode.
* **Backend & Database:**
    * [Firebase](https://firebase.google.com/): Platform pengembangan aplikasi dari Google.
    * **Firebase Authentication:** Untuk menangani autentikasi pengguna.
    * **Cloud Firestore:** Database NoSQL untuk menyimpan data entri jurnal dan profil pengguna.
    * **Firebase Functions:** Untuk menjalankan logika backend di server (seperti pada `functions/src/index.ts`), terutama untuk berinteraksi dengan API eksternal.
* **Kecerdasan Buatan (AI):**
    * **Google Gemini API:** Digunakan di dalam Firebase Functions untuk menggerakkan fitur AI seperti Chatbot dan Refleksi Jurnal.

---

## 📂 Struktur Proyek

```
aplikasi-mood-tracker/ 
    ├── android/ # Kode spesifik Android 
    ├── ios/ # Kode spesifik iOS 
    ├── lib/ # Kode utama aplikasi Flutter (Dart) 
    │ ├── main.dart # Titik masuk utama aplikasi 
    │ ├── home_page.dart # Halaman utama setelah login 
    │ ├── login_page.dart # Halaman login 
    │ ├── register_page.dart # Halaman registrasi 
    │ ├── add_entry_page.dart # Halaman tambah entri mood 
    │ ├── history_page.dart # Halaman riwayat mood 
    │ ├── statistics_page.dart # Halaman statistik 
    │ ├── chatbot_page.dart # Halaman AI Chatbot 
    │ └── reflection_page.dart # Halaman refleksi AI 
    ├── functions/ # Kode backend (Firebase Functions - TypeScript) 
    │ └── src/ 
    │ └── index.ts # Logika backend untuk fitur AI 
    ├── assets/ # Aset statis seperti gambar dan font 
    │ ├── images/ 
    │ └── fonts/ 
    └── pubspec.yaml # Konfigurasi proyek Flutter dan dependensi
```
---

## 🏁 Memulai (Getting Started)

Untuk menjalankan proyek ini secara lokal, ikuti langkah-langkah berikut:

**Prasyarat:**
* [Flutter SDK](https://flutter.dev/docs/get-started/install)
* [Node.js](https://nodejs.org/) (untuk Firebase Functions)
* Akun [Firebase](https://firebase.google.com/)

**1. Konfigurasi Frontend (Flutter):**
   
   a. **Clone repositori:**
      ```
      git clone [https://github.com/username/aplikasi-mood-tracker.git](https://github.com/username/aplikasi-mood-tracker.git)
      cd aplikasi-mood-tracker
      ```
   
   b. **Instal dependensi Flutter:**
      ```
      flutter pub get
      ```
   
   c. **Konfigurasi Firebase:**
      * Buat proyek baru di Firebase Console.
      * Tambahkan aplikasi Android dan/atau iOS.
      * Unduh file `google-services.json` (untuk Android) dan letakkan di `android/app/`.
      * Unduh file `GoogleService-Info.plist` (untuk iOS) dan letakkan di `ios/Runner/`.

   d. **Jalankan aplikasi:**
      ```
      flutter run
      ```

**2. Konfigurasi Backend (Firebase Functions):**

   a. **Navigasi ke direktori functions:**
      ```
      cd functions
      ```
   
   b. **Instal dependensi Node.js:**
      ```
      npm install
      ```
   
   c. **Deploy functions:**
      * Pastikan Anda telah login ke Firebase CLI (`firebase login`).
      * Deploy functions Anda:
          ```
          firebase deploy --only functions
          ```
