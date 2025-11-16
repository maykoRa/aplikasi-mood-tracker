// functions/src/index.ts
import {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentDeleted,
} from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as functionsV1 from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { GoogleGenerativeAI } from "@google/generative-ai";
import * as logger from "firebase-functions/logger";

admin.initializeApp();
const db = admin.firestore();

// ==================== BATCH DELETE HELPER ====================
async function deleteCollection(
  collectionRef: admin.firestore.CollectionReference,
  batchSize: number = 500
) {
  const snapshot = await collectionRef.limit(batchSize).get();
  if (snapshot.empty) return;

  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();

  // Rekursif jika masih ada
  await deleteCollection(collectionRef, batchSize);
}

// ==================== REFLECTION PER ENTRY (EXISTING) ====================
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
    if (!data?.mood || !data?.journal || !data?.userId || data.reflection)
      return;

    const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
    if (!GEMINI_API_KEY) {
      await snapshot.ref.update({ reflection: "Error: AI Key hilang." });
      return;
    }

    let text = null;
    let errorMsg = "";
    let retryCount = 0;
    const maxRetries = 2;

    while (!text && retryCount < maxRetries) {
      try {
        const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
        const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
        // Memanggil method text()
        const result = await model.generateContent(
          SYSTEM_PROMPT_REFLECTION(data.mood, data.journal)
        );
        text = result.response.text().trim();
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
        reflection: text,
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

// ==================== REGENERATE ON UPDATE (EXISTING) ====================
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
      await afterSnapshot.ref.update({
        reflection: "Error: AI Key hilang saat update.",
      });
      return;
    }

    let text = null;
    let errorMsg = "";
    let retryCount = 0;
    const maxRetries = 2;

    while (!text && retryCount < maxRetries) {
      try {
        const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
        const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
        // Memanggil method text()
        const result = await model.generateContent(
          SYSTEM_PROMPT_REFLECTION(data.mood, data.journal)
        );
        text = result.response.text().trim();
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
        reflection: text,
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

// ==================== DAILY SUMMARY (Rekomendasi Keseluruhan - EXISTING)====================
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

      const journal = entriesSnap.docs
        .map((doc) => {
          const d = doc.data();
          const date =
            d.timestamp?.toDate().toLocaleDateString("id-ID") || "Unknown";
          return `- ${date}: Mood "${d.mood}", Jurnal: "${d.journal}"`;
        })
        .join("\n");

      const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
      if (!GEMINI_API_KEY) return; 

      const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
      const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
      const result = await model.generateContent(
        SYSTEM_PROMPT_SUMMARY(journal)
      );
      // Memanggil method text()
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
          { merge: true }
        );

      logger.log(`Summary generated: ${summary.substring(0, 50)}...`);
    } catch (error: any) {
      logger.error("Summary Error:", error.message);
    }
  }
);


// ==================== NEW: DAILY REFLECTION FOR REFLECTION PAGE ====================

// Prompt baru untuk merangkum kegiatan dan memberikan motivasi harian.
const SYSTEM_PROMPT_DAILY_REFLECTION = (dailyJournal: string) => `
Sebagai AI refleksi harian. JANGAN PERNAH memperkenalkan diri. Langsung berikan hasil.
Berikut adalah rangkuman semua kegiatan dan perasaan user hari ini:
${dailyJournal}

Tugas:
1. **Rangkum Kegiatan:** Dari teks di atas, ekstrak dan rangkum semua kegiatan/aktivitas utama user hari ini menjadi 3-5 poin singkat (maks 1 kalimat per poin).
2. **Motivasi:** Berdasarkan rangkuman kegiatan tersebut, berikan 1 MOTIVASI singkat (maks 2 kalimat) yang positif dan membangun untuk hari esok atau untuk mengapresiasi hari ini.

Format respons HANYA dalam JSON berikut:
{
  "summary": ["Poin kegiatan 1", "Poin kegiatan 2", "Poin kegiatan 3"],
  "motivation": "Kalimat motivasi yang singkat dan positif."
}
JANGAN gunakan format lain, JANGAN berikan penjelasan di luar JSON. Gunakan bahasa Indonesia santai.
`;

/**
 * Helper: Mengkonversi string tanggal (YYYY-MM-DD) ke rentang Timestamp (awal dan akhir hari)
 */
function getDateRange(dateString: string): { start: admin.firestore.Timestamp; end: admin.firestore.Timestamp } {
  const date = new Date(dateString);
  date.setHours(0, 0, 0, 0);
  const start = admin.firestore.Timestamp.fromDate(date);

  const endOfDay = new Date(dateString);
  endOfDay.setHours(23, 59, 59, 999);
  const end = admin.firestore.Timestamp.fromDate(endOfDay);

  return { start, end };
}

// === getDailyReflection (FIXED & STABIL) ===
export const getDailyReflection = onCall(
  {
    region: "asia-southeast2",
    secrets: ["GEMINI_API_KEY"],
    timeoutSeconds: 60,
    memory: "512MiB",
  },
  async (request) => {
    const userId = request.auth?.uid;
    const dateString = request.data.date as string;

    if (!userId || !dateString) {
      throw new HttpsError("invalid-argument", "Data tidak lengkap.");
    }

    const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
    if (!GEMINI_API_KEY) {
      throw new HttpsError("internal", "API Key hilang.");
    }

    try {
      const { start, end } = getDateRange(dateString);

      const entriesSnap = await db
        .collection("mood_entries")
        .where("userId", "==", userId)
        .where("timestamp", ">=", start)
        .where("timestamp", "<=", end)
        .orderBy("timestamp", "desc")
        .get();

      if (entriesSnap.empty) {
        return {
          summary: ["Belum ada entri jurnal hari ini."],
          motivation: "Mulai catat perasaanmu sekarang!",
        };
      }

      const journals = entriesSnap.docs
        .map((d) => `${d.data().mood}: ${d.data().journal}`)
        .join("\n---\n");

      const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
      const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

      // GUNAKAN SYSTEM_PROMPT_DAILY_REFLECTION!
      const prompt = SYSTEM_PROMPT_DAILY_REFLECTION(journals);

      const result = await model.generateContent(prompt);
      const text = result.response.text().trim();

      let summary: string[] = [];
      let motivation = "Terus semangat!";

      try {
        const cleaned = text.replace(/```json|```/g, "").trim();
        const json = JSON.parse(cleaned);
        summary = Array.isArray(json.summary) ? json.summary.slice(0, 5) : [];
        motivation = json.motivation || motivation;
      } catch (e) {
        logger.warn("Gagal parse JSON dari AI", { text, error: e });
        summary = journals.split("\n---\n").slice(0, 5).map(s => s.substring(0, 120));
      }

      return { summary, motivation };
    } catch (error: any) {
      logger.error("getDailyReflection Error:", {
        message: error.message,
        userId,
        dateString,
      });
      throw new HttpsError("internal", "Gagal proses AI: " + error.message);
    }
  }
);


// ==================== CHATBOT (EXISTING) ====================
export const sendChatMessage = onCall(
  {
    region: "asia-southeast2",
    secrets: ["GEMINI_API_KEY"],
    timeoutSeconds: 60,
    memory: "1GiB",
  },
  async (request) => {
    const { userId, message, chatId } = request.data;
    if (!userId || !message) throw new Error("Missing userId or message");

    const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
    if (!GEMINI_API_KEY) throw new Error("API Key missing");

    try {
      let sessionRef;
      if (chatId) {
        sessionRef = db
          .collection("users")
          .doc(userId)
          .collection("chats")
          .doc(chatId);
        const doc = await sessionRef.get();
        if (!doc.exists) throw new Error("Chat session not found");
      } else {
        sessionRef = db
          .collection("users")
          .doc(userId)
          .collection("chats")
          .doc();
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
      const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
      const currentSummary =
        (await sessionRef.get()).data()?.summary || "Percakapan dimulai.";
      const recentSnap = await sessionRef
        .collection("messages")
        .orderBy("timestamp", "desc")
        .limit(2)
        .get();
      const recentMessages = recentSnap.docs
        .reverse()
        .map((doc) => {
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

      // Memanggil method text()
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
        const allSnap = await sessionRef
          .collection("messages")
          .orderBy("timestamp")
          .get();
        const fullHistory = allSnap.docs
          .map((doc) => {
            const d = doc.data();
            return `${d.role === "user" ? "User" : "MoodBuddy"}: ${d.message}`;
          })
          .join("\n");

        const summaryPrompt = `
          Ringkas percakapan ini dalam 1 kalimat (maks 25 kata):
          "${fullHistory}"
          Fokus emosi user dan saran MoodBuddy.
        `;
        // Memanggil method text()
        const summaryResult = await model.generateContent(summaryPrompt);
        const newSummary = summaryResult.response.text().trim();
        await sessionRef.update({ summary: newSummary });
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

// ==================== CLEANUP CHAT MESSAGES (EXISTING) ====================
export const cleanupChatMessages = onDocumentDeleted(
  {
    document: "users/{userId}/chats/{chatId}",
    region: "asia-southeast2",
    timeoutSeconds: 300,
    memory: "1GiB",
  },
  async (event) => {
    const userId = event.params.userId;
    const chatId = event.params.chatId;

    logger.log(`[CHAT DELETED] Membersihkan messages untuk chat: ${chatId}`);

    const messagesRef = db
      .collection("users")
      .doc(userId)
      .collection("chats")
      .doc(chatId)
      .collection("messages");

    try {
      await deleteCollection(messagesRef);
      logger.log(
        `[CHAT DELETED] Berhasil hapus messages untuk chat: ${chatId}`
      );
    } catch (error: any) {
      logger.error(`[CHAT DELETED] Gagal hapus messages:`, error);
    }
  }
);

// ==================== CLEANUP USER DATA (v1 - EXISTING) ====================
export const cleanupUserDataOnDelete = functionsV1
  .region("asia-southeast2")
  .auth.user()
  .onDelete(async (user) => {
    const uid = user.uid;
    logger.log(`[USER DELETED] Membersihkan data untuk user: ${uid}`);

    try {
      // 1. Hapus mood_entries
      const moodQuery = db
        .collection("mood_entries")
        .where("userId", "==", uid);
      const moodSnap = await moodQuery.get();
      if (!moodSnap.empty) {
        const batch = db.batch();
        moodSnap.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
        logger.log(`[USER DELETED] Hapus ${moodSnap.size} mood_entries`);
      }

      // 2. Hapus user doc + subcollections
      const userDocRef = db.collection("users").doc(uid);
      await deleteCollection(userDocRef.collection("chats"));
      await deleteCollection(userDocRef.collection("summary"));
      await userDocRef.delete();

      logger.log(`[USER DELETED] Selesai bersihkan data user: ${uid}`);
    } catch (error: any) {
      logger.error(`[USER DELETED] Error:`, error);
    }
  });