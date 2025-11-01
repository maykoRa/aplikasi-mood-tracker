// functions/src/index.ts
import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import {GoogleGenerativeAI} from "@google/generative-ai";

admin.initializeApp();

// === FUNCTION 1: Refleksi Diri per entri (Penamaan Ulang & Prompt) ===
const SYSTEM_PROMPT_REFLECTION = (mood: string, journal: string) => `
Sebagai AI refleksi, JANGAN PERNAH memperkenalkan diri. Langsung berikan inti refleksi.
Analisis mood: "${mood}" dan jurnal: "${journal}".
Berikan 1 REFLEKSI DIRI singkat (maks 2 kalimat) yang bersifat positif, membangun, dan sesuai dengan perasaan dan isi jurnal user.
Gunakan bahasa Indonesia santai. JANGAN gunakan emoji.
`;

// Nama fungsi diubah menjadi generateReflection dan akan mengupdate field 'reflection'
export const generateReflection = onDocumentCreated(
  {
    document: "mood_entries/{entryId}",
    region: "asia-southeast2",
    secrets: ["GEMINI_API_KEY"],
    timeoutSeconds: 300,
    memory: "512MiB",
    cpu: 1,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    // Cek apakah entri ini sudah memiliki refleksi (field baru)
    if (!data?.mood || !data?.journal || !data?.userId || data.reflection) return;

    const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
    if (!GEMINI_API_KEY) {
      // PERBAIKAN: Menggunakan optional chaining atau memastikan snapshot non-null
      await snapshot.ref.update({reflection: "Error: AI Key hilang."});
      return;
    }

    let text = null;
    let errorMsg = "";
    let retryCount = 0;
    const maxRetries = 2;

    while (!text && retryCount < maxRetries) {
      try {
        const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
        const model = genAI.getGenerativeModel({model: "gemini-2.5-flash"});

        const result = await model.generateContent(
          // UBAH ke prompt refleksi yang baru
          SYSTEM_PROMPT_REFLECTION(data.mood, data.journal));
        text = result.response.text();
        break;
      } catch (error: any) {
        errorMsg = error.message || "Unknown error";
        if (errorMsg.includes("429")) {
          await new Promise((r) => setTimeout(r, 30000));
          retryCount++;
        } else break;
      }
    }

    if (text) {
      // PERBAIKAN: Menggunakan optional chaining/memastikan snapshot non-null
      await snapshot.ref.update({
        reflection: text.trim(),
        reflectedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      // PERBAIKAN: Menggunakan optional chaining/memastikan snapshot non-null
      await snapshot.ref.update({
        reflection: "Maaf, AI sedang sibuk. Coba lagi nanti.",
        errorLog: errorMsg.substring(0, 500),
      });
    }
  }
);

// === FUNCTION 3: Meregenerasi Refleksi saat Entri di-Update ===
export const regenerateReflectionOnUpdate = onDocumentUpdated(
  {
    document: "mood_entries/{entryId}",
    region: "asia-southeast2",
    secrets: ["GEMINI_API_KEY"],
    timeoutSeconds: 300,
    memory: "512MiB",
    cpu: 1,
  },
  async (event) => {
    // Pengamanan sudah benar, tapi kita tambahkan pengamanan di bawah
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const afterSnapshot = event.data?.after; // Ambil snapshot setelah

    if (!before || !after || !afterSnapshot) return; // Tambahkan pengamanan untuk afterSnapshot

    // Syarat 1: Hanya jalankan jika field 'journal' berubah
    const journalChanged = before.journal !== after.journal;

    // Syarat 2: Hanya jalankan jika field 'reflection' sengaja di-set ke null oleh client (saat update)
    const reflectionCleared = after.reflection === null;

    // JANGAN JALANKAN jika jurnal tidak berubah ATAU reflection tidak di-set null
    if (!journalChanged || !reflectionCleared) return;

    // PERBAIKAN: Mengakses ref dari afterSnapshot yang sudah dipastikan non-null
    await afterSnapshot.ref.update({
      dailySummaryTriggered: admin.firestore.FieldValue.delete(),
    });

    const data = after;

    const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
    if (!GEMINI_API_KEY) {
      // PERBAIKAN: Mengakses ref dari afterSnapshot
      await afterSnapshot.ref.update({reflection: "Error: AI Key hilang saat update."});
      return;
    }

    let text = null;
    let errorMsg = "";
    let retryCount = 0;
    const maxRetries = 2;

    // Logika generasi AI diulang sama persis dengan generateReflection
    while (!text && retryCount < maxRetries) {
      try {
        const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
        const model = genAI.getGenerativeModel({model: "gemini-2.5-flash"});
        const result = await model.generateContent(
          SYSTEM_PROMPT_REFLECTION(data.mood, data.journal));
        text = result.response.text();
        break;
      } catch (error: any) {
        errorMsg = error.message || "Unknown error";
        if (errorMsg.includes("429")) {
          await new Promise((r) => setTimeout(r, 30000));
          retryCount++;
        } else break;
      }
    }

    if (text) {
      // PERBAIKAN: Mengakses ref dari afterSnapshot
      await afterSnapshot.ref.update({
        reflection: text.trim(),
        reflectedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      // PERBAIKAN: Mengakses ref dari afterSnapshot
      await afterSnapshot.ref.update({
        reflection: "Maaf, AI sedang sibuk saat update. Coba lagi nanti.",
        errorLog: errorMsg.substring(0, 500),
      });
    }
  }
);

// === FUNCTION 2: Rekomendasi Keseluruhan (Perbaikan Prompt & Logika 7 hari) ===
const SYSTEM_PROMPT_SUMMARY = (journal: string) => `
Sebagai AI psikolog, JANGAN PERNAH memperkenalkan diri. Langsung berikan inti rekomendasi.
Berikut adalah rangkuman entri mood dan jurnal user dalam 7 hari terakhir:

${journal}

Analisis pola mood, emosi, dan kebiasaan user.
Berikan 3 poin rekomendasi utama hari ini, **setiap poin harus satu kalimat pendek**. 
**JANGAN GUNAKAN LEBIH DARI 3 KALIMAT TOTAL.**
Format respons HANYA dalam 3 kalimat, tanpa poin, tanpa daftar.
Contoh: 'Fokus pada pola tidurmu minggu ini. Luangkan waktu 10 menit untuk journaling di pagi hari. Beri dirimu apresiasi untuk pencapaian kecil.'
`;

export const generateDailySummary = onDocumentCreated(
  {
    document: "mood_entries/{entryId}",
    region: "asia-southeast2",
    secrets: ["GEMINI_API_KEY"],
    timeoutSeconds: 300,
    memory: "1GiB",
    cpu: 1,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    if (!data?.userId) return;

    const userId = data.userId;
    const db = admin.firestore();

    try {
      // Logika 7 hari sudah benar, menggunakan timestamp 7 hari yang lalu
      const sevenDaysAgo = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
      );

      const entriesSnap = await db
        .collection("mood_entries")
        .where("userId", "==", userId)
        .where("timestamp", ">=", sevenDaysAgo)
        .orderBy("timestamp", "desc")
        .get();

      if (entriesSnap.empty) return;

      const entriesText = entriesSnap.docs
        .map((doc) => {
          const d = doc.data();
          const date = d.timestamp?.toDate().toLocaleDateString("id-ID") || "Unknown";
          return `- ${date}: Mood "${d.mood}", Jurnal: "${d.journal}"`;
        })
        .join("\n");

      const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY!);
      const model = genAI.getGenerativeModel({model: "gemini-2.5-flash"});

      // Gunakan prompt summary yang sudah diperketat
      const result = await model.generateContent(SYSTEM_PROMPT_SUMMARY(entriesText));
      const summary = result.response.text().trim();

      await db
        .collection("users")
        .doc(userId)
        .collection("summary")
        .doc("daily")
        .set({
          recommendation: summary,
          generatedAt: admin.firestore.FieldValue.serverTimestamp(),
          periodStart: sevenDaysAgo,
          entryCount: entriesSnap.size,
        }, {merge: true});

      console.log(`Summary generated: ${summary.substring(0, 50)}...`);
    } catch (error: any) {
      console.error("Summary Error:", error.message);
    }
  }
);
