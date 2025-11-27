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

/* ======================= PERSONA SYSTEM ====================== */

type PersonaType = "formal" | "tough" | "friendly" | "coach" | "motherly" | "bestie";

const PERSONA_PROMPTS_REFLECTION: Record<
  PersonaType,
  (mood: string, journal: string) => string
> = {
  formal: (mood, journal) => `
Kamu adalah konsultan psikologi profesional, sopan, dan terstruktur.
Mood: "${mood}", Jurnal: "${journal}".
Berikan 1 refleksi singkat (maks 2 kalimat) yang objektif, menggunakan bahasa baku, dan memberikan insight psikologis ringan.
Gunakan kata "Anda", hindari bahasa gaul dan emoji.
`,

  tough: (mood, journal) => `
Kamu adalah mentor keras yang tegas dan disiplin (tough love). Tidak ada alasan diterima.
Mood: "${mood}", Jurnal: "${journal}".
Berikan 1 refleksi keras (maks 2 kalimat) yang memaksa user bangun dan berubah SEKARANG. Gunakan bahasa tegas, langsung, tanpa kasih sayang berlebih.
`,

  friendly: (mood, journal) => `
Kamu adalah sahabat dekat yang suportif, hangat, dan selalu ada.
Mood: "${mood}", Jurnal: "${journal}".
Berikan 1 refleksi singkat (maks 2 kalimat) penuh dukungan, empati, dan semangat positif. Boleh pakai "sayang", "gapapa kok", "aku ada buat kamu".
`,

  coach: (mood, journal) => `
Kamu adalah life coach energik dan penuh motivasi.
Mood: "${mood}", Jurnal: "${journal}".
Berikan 1 refleksi singkat (maks 2 kalimat) yang membakar semangat, penuh energi, dan mendorong user untuk action besar. Gunakan kata-kata seperti "Come on!", "Kamu bisa!", "Gaspol!".
`,

  motherly: (mood, journal) => `
Kamu adalah sosok ibu yang penuh kasih, mengayomi, dan bijaksana.
Mood: "${mood}", Jurnal: "${journal}".
Berikan 1 refleksi hangat (maks 2 kalimat) yang menenangkan, penuh kasih sayang, dan bijak. Boleh pakai "nak", "sayang", "mama ada di sini", "peluk mama".
`,

  bestie: (mood, journal) => `
Kamu adalah bestie gaul yang santai, lucu, dan selalu relate.
Mood: "${mood}", Jurnal: "${journal}".
Berikan 1 refleksi singkat (maks 2 kalimat) dengan bahasa anak muda kekinian, santai banget, pake "gila", "wkwk", "duh", "yakin lu?", "gas lah".
`,
};

const PERSONA_PROMPTS_SUMMARY: Record<PersonaType, (journal: string) => string> = {
  formal: (journal) => `
Kamu konsultan profesional. Analisis 7 hari terakhir: ${journal}
Berikan 3 rekomendasi objektif dan terstruktur untuk meningkatkan kesejahteraan. Maksimal 3 kalimat, bahasa baku, tanpa emosi berlebih.
`,

  tough: (journal) => `
Kamu mentor tegas. Analisis 7 hari terakhir: ${journal}
Berikan 3 perintah keras yang harus dilakukan user mulai hari ini. Maksimal 3 kalimat, tanpa basa-basi, tanpa kata penyemangat.
`,

  friendly: (journal) => `
Kamu sahabat dekat yang suportif. Analisis 7 hari terakhir: ${journal}
Berikan 3 saran hangat dan penuh dukungan untuk hari ini. Maksimal 3 kalimat, boleh pakai "yuk", "kamu pasti bisa", "aku bangga sama kamu".
`,

  coach: (journal) => `
Kamu life coach energik. Analisis 7 hari terakhir: ${journal}
Berikan 3 rekomendasi penuh semangat untuk level up hari ini! Maksimal 3 kalimat, gunakan bahasa motivasi tinggi: "Gaspol!", "Ini waktunya!", "You got this!".
`,

  motherly: (journal) => `
Kamu ibu yang bijak dan penuh kasih. Analisis 7 hari terakhir: ${journal}
Berikan 3 nasihat lembut tapi tegas untuk anak mama. Maksimal 3 kalimat, gunakan "nak", "sayang", "mama tahu kamu bisa", "istirahat dulu ya".
`,

  bestie: (journal) => `
Kamu bestie gaul. Analisis 7 hari terakhir: ${journal}
Kasih 3 saran santai tapi ngena banget buat hari ini. Maksimal 3 kalimat, pake bahasa anak Jaksel: "gila", "wkwkwk", "serius lu?", "udah move on belum?", "gas lah bro!".
`,
};

/* Helper: ambil persona user (default = friendly) */
async function getUserPersona(userId: string): Promise<PersonaType> {
  try {
    const doc = await db.collection("users").doc(userId).get();
    const p = doc.data()?.aiPersona as PersonaType;
    if (p && ["formal","tough","friendly","coach","motherly","bestie"].includes(p)) {
      return p;
    }
  } catch (e) {
    logger.warn("Gagal ambil persona, pakai default friendly", e);
  }
  return "friendly"; // default
}

/* ======================= MOOD DETECTION ====================== */

const SYSTEM_PROMPT_MOOD_ACCURATE = (journal: string) => `
Analisis jurnal berikut dan tentukan mood user SECARA AKURAT.

Jurnal:
"${journal}"

Pilihan mood (PASTIKAN HANYA SALAH SATU DARI INI):
- Sangat Baik
- Baik
- Biasa Saja
- Buruk
- Sangat Buruk

Balas HANYA dengan salah satu teks di atas. Tanpa penjelasan, tanpa emoji.
`;

export const detectAndSetMood = onDocumentCreated(
  {
    document: "mood_entries/{entryId}",
    region: "asia-southeast2",
    secrets: ["GEMINI_API_KEY"],
    timeoutSeconds: 60,
    memory: "512MiB",
    cpu: 1,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const data = snapshot.data();
    if (!data?.journal || (data.mood !== "Menunggu AI..." && data.mood !== null))
      return;

    const journal = data.journal as string;
    if (journal.trim().length < 10) {
      await snapshot.ref.update({ mood: "Biasa Saja" });
      return;
    }

    const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
    if (!GEMINI_API_KEY) {
      await snapshot.ref.update({ mood: "Biasa Saja" });
      return;
    }

    try {
      const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
      const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
      const result = await model.generateContent(
        SYSTEM_PROMPT_MOOD_ACCURATE(journal)
      );
      let detected = result.response.text().trim();

      const valid = ["Sangat Baik", "Baik", "Biasa Saja", "Buruk", "Sangat Buruk"];
      const finalMood = valid.find((m) => detected.includes(m)) || "Biasa Saja";

      await snapshot.ref.update({
        mood: finalMood,
        moodDetectedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e: any) {
      logger.error("Mood detection error:", e);
      await snapshot.ref.update({ mood: "Biasa Saja" });
    }
  }
);

export const detectAndSetMoodOnUpdate = onDocumentUpdated(
  {
    document: "mood_entries/{entryId}",
    region: "asia-southeast2",
    secrets: ["GEMINI_API_KEY"],
    timeoutSeconds: 60,
    memory: "512MiB",
    cpu: 1,
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const snapshot = event.data?.after;
    if (!before || !after || !snapshot) return;

    const moodReset = after.mood === "Menunggu AI..." && before.mood !== "Menunggu AI...";
    const journalChanged = before.journal !== after.journal;
    if (!moodReset && !journalChanged) return;

    if (!after.journal || after.journal.trim().length < 10) {
      await snapshot.ref.update({ mood: "Biasa Saja" });
      return;
    }

    const journal = after.journal as string;
    const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
    if (!GEMINI_API_KEY) {
      await snapshot.ref.update({ mood: "Biasa Saja" });
      return;
    }

    try {
      const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
      const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
      const result = await model.generateContent(
        SYSTEM_PROMPT_MOOD_ACCURATE(journal)
      );
      let detected = result.response.text().trim();

      const valid = ["Sangat Baik", "Baik", "Biasa Saja", "Buruk", "Sangat Buruk"];
      const finalMood = valid.find((m) => detected.includes(m)) || "Biasa Saja";

      await snapshot.ref.update({
        mood: finalMood,
        moodDetectedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e: any) {
      logger.error("Mood update detection error:", e);
      await snapshot.ref.update({ mood: "Biasa Saja" });
    }
  }
);

/* ==================== REFLECTION PER ENTRY =================== */

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

    const persona = await getUserPersona(data.userId);
    const prompt = PERSONA_PROMPTS_REFLECTION[persona](data.mood, data.journal);

    const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
    if (!GEMINI_API_KEY) {
      await snapshot.ref.update({ reflection: "Error: AI Key hilang." });
      return;
    }

    let text = null;
    let retry = 0;
    const maxRetries = 2;

    while (!text && retry < maxRetries) {
      try {
        const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
        const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
        const result = await model.generateContent(prompt);
        text = result.response.text().trim();
        break;
      } catch (e: any) {
        if (e.message?.includes("429")) {
          await new Promise((r) => setTimeout(r, 30000));
          retry++;
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
      });
    }
  }
);

/* =============== REGENERATE REFLECTION ON UPDATE ============= */

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
    const snapshot = event.data?.after;
    if (!before || !after || !snapshot) return;

    const journalChanged = before.journal !== after.journal;
    const reflectionCleared = after.reflection === null;
    if (!journalChanged || !reflectionCleared) return;

    const persona = await getUserPersona(after.userId);
    const prompt = PERSONA_PROMPTS_REFLECTION[persona](after.mood, after.journal);

    const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
    if (!GEMINI_API_KEY) {
      await snapshot.ref.update({ reflection: "Error: AI Key hilang." });
      return;
    }

    let text = null;
    let retry = 0;
    const maxRetries = 2;

    while (!text && retry < maxRetries) {
      try {
        const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
        const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
        const result = await model.generateContent(prompt);
        text = result.response.text().trim();
        break;
      } catch (e: any) {
        if (e.message?.includes("429")) {
          await new Promise((r) => setTimeout(r, 30000));
          retry++;
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
        reflection: "Maaf, AI sedang sibuk saat update.",
      });
    }
  }
);

/* ==================== DAILY SUMMARY (7 HARI) ================= */

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

      const journalText = entriesSnap.docs
        .map((doc) => {
          const d = doc.data();
          const date =
            d.timestamp?.toDate().toLocaleDateString("id-ID") || "Unknown";
          return `- ${date}: Mood "${d.mood}", Jurnal: "${d.journal}"`;
        })
        .join("\n");

      const persona = await getUserPersona(userId);
      const prompt = PERSONA_PROMPTS_SUMMARY[persona](journalText);

      const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
      if (!GEMINI_API_KEY) return;

      const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
      const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
      const result = await model.generateContent(prompt);
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
    } catch (e: any) {
      logger.error("Daily summary error:", e);
    }
  }
);

/* ====================== DAILY REFLECTION ===================== */

const SYSTEM_PROMPT_DAILY_REFLECTION = (dailyJournal: string) => `
Sebagai AI refleksi harian. JANGAN PERNAH memperkenalkan diri. Langsung berikan hasil.
Berikut adalah rangkuman semua kegiatan dan perasaan user hari ini:
${dailyJournal}

Tugas:
1. Rangkum Kegiatan: ekstrak dan rangkum semua kegiatan utama menjadi 3-5 poin singkat.
2. Motivasi: berikan 1 motivasi singkat (maks 2 kalimat) yang positif.

Format respons HANYA JSON:
{
  "summary": ["poin 1", "poin 2", ...],
  "motivation": "Kalimat motivasi."
}
Gunakan bahasa Indonesia santai.
`;

type TimestampRange = { start: admin.firestore.Timestamp; end: admin.firestore.Timestamp };

function getDateRange(dateString: string): TimestampRange {
  const date = new Date(dateString);
  date.setHours(0, 0, 0, 0);
  const start = admin.firestore.Timestamp.fromDate(date);
  const endOfDay = new Date(dateString);
  endOfDay.setHours(23, 59, 59, 999);
  const end = admin.firestore.Timestamp.fromDate(endOfDay);
  return { start, end };
}

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
    if (!userId || !dateString) throw new HttpsError("invalid-argument", "Data tidak lengkap.");

    const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
    if (!GEMINI_API_KEY) throw new HttpsError("internal", "API Key hilang.");

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
      const result = await model.generateContent(SYSTEM_PROMPT_DAILY_REFLECTION(journals));
      const text = result.response.text().trim();

      let summary: string[] = [];
      let motivation = "Terus semangat!";

      try {
        const cleaned = text.replace(/```json|```/g, "").trim();
        const json = JSON.parse(cleaned);
        summary = Array.isArray(json.summary) ? json.summary.slice(0, 5) : [];
        motivation = json.motivation || motivation;
      } catch {
        summary = journals.split("\n---\n").slice(0, 5).map((s) => s.substring(0, 120));
      }

      return { summary, motivation };
    } catch (e: any) {
      logger.error("getDailyReflection error:", e);
      throw new HttpsError("internal", "Gagal proses AI.");
    }
  }
);

/* ========================== CHATBOT ========================== */

export const sendChatMessage = onCall(
  {
    region: "asia-southeast2",
    secrets: ["GEMINI_API_KEY"],
    timeoutSeconds: 60,
    memory: "1GiB",
  },
  async (request) => {
    const { userId, message, chatId } = request.data;
    if (!userId || !message) throw new Error("Missing data");

    const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
    if (!GEMINI_API_KEY) throw new Error("API Key missing");

    try {
      let sessionRef;
      if (chatId) {
        sessionRef = db.collection("users").doc(userId).collection("chats").doc(chatId);
        if (!(await sessionRef.get()).exists) throw new Error("Chat not found");
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
        message,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
      await sessionRef.update({
        lastMessage: admin.firestore.FieldValue.serverTimestamp(),
        messageCount: admin.firestore.FieldValue.increment(1),
      });

      const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
      const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
      const summary = (await sessionRef.get()).data()?.summary || "Percakapan dimulai.";
      const recent = await sessionRef
        .collection("messages")
        .orderBy("timestamp", "desc")
        .limit(2)
        .get();
      const recentText = recent.docs
        .reverse()
        .map((d) => (d.data().role === "user" ? "User" : "MoodBuddy") + ": " + d.data().message)
        .join("\n");

      const prompt = `
        Kamu adalah "MoodBuddy", psikolog ramah.
        Konteks sebelumnya: "${summary}"
        Pesan terbaru:
        ${recentText}
        Balas singkat (1-2 kalimat), empati, bahasa Indonesia santai.
        JANGAN ulangi konteks. JANGAN pakai emoji.
      `;

      const result = await model.generateContent(prompt);
      const reply = result.response.text().trim();

      await sessionRef.collection("messages").add({
        role: "ai",
        message: reply,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
      await sessionRef.update({
        lastMessage: admin.firestore.FieldValue.serverTimestamp(),
        messageCount: admin.firestore.FieldValue.increment(1),
      });

      return { reply, chatId: sessionRef.id };
    } catch (e: any) {
      logger.error("Chat error:", e);
      throw new Error("Gagal: " + e.message);
    }
  }
);

/* ======================= CLEANUP & ETC ======================= */

async function deleteCollection(
  collectionRef: admin.firestore.CollectionReference,
  batchSize = 500
) {
  const snapshot = await collectionRef.limit(batchSize).get();
  if (snapshot.empty) return;
  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
  await deleteCollection(collectionRef, batchSize);
}

export const cleanupChatMessages = onDocumentDeleted(
  { document: "users/{userId}/chats/{chatId}", region: "asia-southeast2" },
  async (event) => {
    const messagesRef = db
      .collection("users")
      .doc(event.params.userId)
      .collection("chats")
      .doc(event.params.chatId)
      .collection("messages");
    await deleteCollection(messagesRef);
  }
);

export const cleanupUserDataOnDelete = functionsV1
  .region("asia-southeast2")
  .auth.user()
  .onDelete(async (user) => {
    const uid = user.uid;
    const moodQuery = db.collection("mood_entries").where("userId", "==", uid);
    const moodSnap = await moodQuery.get();
    if (!moodSnap.empty) {
      const batch = db.batch();
      moodSnap.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }
    const userDocRef = db.collection("users").doc(uid);
    await deleteCollection(userDocRef.collection("chats"));
    await deleteCollection(userDocRef.collection("summary"));
    await userDocRef.delete();
  });