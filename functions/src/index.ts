// functions/src/index.ts
import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import {onCall} from "firebase-functions/v2/https";
import * as functionsV1 from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {GoogleGenerativeAI} from "@google/generative-ai";
import * as logger from "firebase-functions/logger";

admin.initializeApp();
const db = admin.firestore(); // DB Global

// === FUNCTION 1: Refleksi Diri per entri (v2) ===
const SYSTEM_PROMPT_REFLECTION = (mood: string, journal: string) => `
Sebagai AI refleksi, JANGAN PERNAH memperkenalkan diri. Langsung berikan inti refleksi.
Analisis mood: "${mood}" dan jurnal: "${journal}".
Berikan 1 REFLEKSI DIRI singkat (maks 2 kalimat) yang bersifat positif, membangun, dan sesuai dengan perasaan dan isi jurnal user.
Gunakan bahasa Indonesia santai. JANGAN gunakan emoji.
`;

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
    if (!data?.mood || !data?.journal || !data?.userId || data.reflection) return;

    const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
    if (!GEMINI_API_KEY) {
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
          SYSTEM_PROMPT_REFLECTION(data.mood, data.journal)
        );
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
      await snapshot.ref.update({
        reflection: text.trim(),
        reflectedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      await snapshot.ref.update({
        reflection: "Maaf, AI sedang sibuk. Coba lagi nanti.",
        errorLog: errorMsg.substring(0, 500),
      });
    }
  }
);

// === FUNCTION 3: Meregenerasi Refleksi saat Entri di-Update (v2) ===
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
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const afterSnapshot = event.data?.after;
    if (!before || !after || !afterSnapshot) return;

    const journalChanged = before.journal !== after.journal;
    const reflectionCleared = after.reflection === null;
    if (!journalChanged || !reflectionCleared) return;

    await afterSnapshot.ref.update({
      dailySummaryTriggered: admin.firestore.FieldValue.delete(),
    });
    const data = after;
    const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
    if (!GEMINI_API_KEY) {
      await afterSnapshot.ref.update({reflection: "Error: AI Key hilang saat update."});
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
          SYSTEM_PROMPT_REFLECTION(data.mood, data.journal)
        );
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
      await afterSnapshot.ref.update({
        reflection: text.trim(),
        reflectedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      await afterSnapshot.ref.update({
        reflection: "Maaf, AI sedang sibuk saat update. Coba lagi nanti.",
        errorLog: errorMsg.substring(0, 500),
      });
    }
  }
);

// === FUNCTION 2: Rekomendasi Keseluruhan (v2) ===
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

    try {
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
      // PERBAIKAN: Tipe 'doc' ditambahkan
        .map((doc: admin.firestore.QueryDocumentSnapshot) => {
          const d = doc.data();
          const date = d.timestamp?.toDate().toLocaleDateString("id-ID") || "Unknown";
          return `- ${date}: Mood "${d.mood}", Jurnal: "${d.journal}"`;
        })
        .join("\n");
      const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY!);
      const model = genAI.getGenerativeModel({model: "gemini-2.5-flash"});
      const result = await model.generateContent(SYSTEM_PROMPT_SUMMARY(entriesText));
      const summary = result.response.text().trim();
      await db
        .collection("users")
        .doc(userId)
        .collection("summary")
        .doc("daily")
        .set(
          {
            recommendation: summary,
            generatedAt: admin.firestore.FieldValue.serverTimestamp(),
            periodStart: sevenDaysAgo,
            entryCount: entriesSnap.size,
          },
          {merge: true}
        );
      logger.log(`Summary generated: ${summary.substring(0, 50)}...`);
    } catch (error: any) {
      logger.error("Summary Error:", error.message);
    }
  }
);

// ====================================================================
// === CHATBOT: Send Message + Dynamic Summary (v2) ===
// ====================================================================

export const sendChatMessage = onCall(
  {
    region: "asia-southeast2",
    secrets: ["GEMINI_API_KEY"],
    timeoutSeconds: 60,
    memory: "1GiB",
  },
  async (request) => {
    const {userId, message, chatId} = request.data;
    if (!userId || !message) throw new Error("Missing userId or message");

    const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
    if (!GEMINI_API_KEY) throw new Error("API Key missing");

    try {
      let sessionRef;
      if (chatId) {
        sessionRef = db.collection("users").doc(userId).collection("chats").doc(chatId);
        const doc = await sessionRef.get();
        if (!doc.exists) throw new Error("Chat session not found");
      } else {
        sessionRef = db.collection("users").doc(userId).collection("chats").doc();
        await sessionRef.set({
          startedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastMessage: admin.firestore.FieldValue.serverTimestamp(),
          messageCount: 0,
          summary: "Percakapan dimulai.",
        });
      }

      await sessionRef.collection("messages").add({
        role: "user",
        message: message,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
      await sessionRef.update({
        lastMessage: admin.firestore.FieldValue.serverTimestamp(),
        messageCount: admin.firestore.FieldValue.increment(1),
      });
      const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
      const model = genAI.getGenerativeModel({model: "gemini-2.5-flash"});
      const currentSummary = (await sessionRef.get()).data()?.summary || "Percakapan dimulai.";
      const recentSnap = await sessionRef.collection("messages")
        .orderBy("timestamp", "desc")
        .limit(2)
        .get();
      const recentMessages = recentSnap.docs
        .reverse()
      // PERBAIKAN: Tipe 'doc' ditambahkan
        .map((doc: admin.firestore.QueryDocumentSnapshot) => {
          const d = doc.data();
          return `${d.role === "user" ? "User" : "MoodBuddy"}: ${d.message}`;
        })
        .join("\n");
      const prompt = `
       Kamu adalah "MoodBuddy", psikolog ramah.
       Konteks sebelumnya: "${currentSummary}"
       Pesan terbaru:
       ${recentMessages}
       Balas singkat (1-2 kalimat), empati, bahasa Indonesia santai.
       JANGAN ulangi konteks. JANGAN pakai emoji.
     `;
      const result = await model.generateContent(prompt);
      const aiResponse = result.response.text().trim();
      await sessionRef.collection("messages").add({
        role: "ai",
        message: aiResponse,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
      await sessionRef.update({
        lastMessage: admin.firestore.FieldValue.serverTimestamp(),
        messageCount: admin.firestore.FieldValue.increment(1),
      });
      const messageCount = (await sessionRef.get()).data()?.messageCount || 0;
      if (messageCount % 3 === 0 && messageCount > 0) {
        const allSnap = await sessionRef.collection("messages")
          .orderBy("timestamp")
          .get();
        const fullHistory = allSnap.docs
        // PERBAIKAN: Tipe 'doc' ditambahkan
          .map((doc: admin.firestore.QueryDocumentSnapshot) => {
            const d = doc.data();
            return `${d.role === "user" ? "User" : "MoodBuddy"}: ${d.message}`;
          })
          .join("\n");
        const summaryPrompt = `
         Ringkas percakapan ini dalam 1 kalimat (maks 25 kata):
         "${fullHistory}"
         Fokus emosi user dan saran MoodBuddy.
       `;
        const summaryResult = await model.generateContent(summaryPrompt);
        const newSummary = summaryResult.response.text().trim();
        await sessionRef.update({summary: newSummary});
        logger.log(`Chat summary updated: ${newSummary}`);
      }
      return {
        reply: aiResponse,
        chatId: sessionRef.id,
      };
    } catch (error: any) {
      logger.error("Chatbot Error:", error.message);
      throw new Error("Gagal: " + error.message);
    }
  }
);


// ====================================================================
// === FUNGSI v1 UNTUK HAPUS DATA PENGGUNA (PERBAIKAN) ===
// ====================================================================

/**
 * Fungsi ini dipicu (triggered) setiap kali sebuah akun
 * Firebase Authentication dihapus. (MENGGUNAKAN SINTAKS v1)
 */
// PERBAIKAN: Gunakan alias 'functionsV1'
export const cleanupUserDataOnDelete = functionsV1
  .region("asia-southeast2")
  .auth.user()
  // PERBAIKAN: Gunakan tipe dari 'functionsV1'
  .onDelete(async (user: functionsV1.auth.UserRecord) => {
    const uid = user.uid;
    logger.log(`[USER DELETED - v1] Mulai membersihkan data untuk user: ${uid}`);

    // -----------------------------------------------------------------
    // ⚠️ PASTIKAN NAMA KOLEKSI DI BAWAH INI SUDAH BENAR ⚠️
    // -----------------------------------------------------------------
    const moodEntriesQuery = db.collection("mood_entries")
      .where("userId", "==", uid);
    const userDocRef = db.collection("users").doc(uid);
    // -----------------------------------------------------------------

    try {
      // PROSES 1: Hapus semua 'mood_entries'
      const moodBatch = db.batch();
      const moodSnapshot = await moodEntriesQuery.get();

      if (moodSnapshot.empty) {
        logger.log(`[USER DELETED - v1] Tidak ada 'mood_entries' ditemukan untuk user: ${uid}`);
      } else {
        logger.log(`[USER DELETED - v1] Menemukan ${moodSnapshot.size} 'mood_entries' untuk dihapus.`);
        // PERBAIKAN: Tipe 'doc' ditambahkan
        moodSnapshot.docs.forEach((doc: admin.firestore.QueryDocumentSnapshot) => {
          moodBatch.delete(doc.ref);
        });
        await moodBatch.commit();
        logger.log(`[USER DELETED - v1] Berhasil menghapus 'mood_entries' untuk ${uid}`);
      }

      // PROSES 2: Hapus dokumen user DAN SEMUA SUB-KOLEKSINYA
      logger.log(`[USER DELETED - v1] Memulai penghapusan rekursif untuk doc: ${userDocRef.path}`);
      await admin.firestore().recursiveDelete(userDocRef);
      logger.log(`[USER DELETED - v1] Berhasil membersihkan semua data (termasuk sub-koleksi) untuk user: ${uid}`);

      return null;
    } catch (error: any) {
      logger.error(`[USER DELETED - v1] Error saat membersihkan data user ${uid}:`, error);
      throw new Error(`Gagal membersihkan data pengguna untuk ${uid}: ${error.message}`);
    }
  });
