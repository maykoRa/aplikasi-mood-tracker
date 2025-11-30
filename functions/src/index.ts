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

type PersonaType =
  | "formal"
  | "tough"
  | "friendly"
  | "coach"
  | "motherly"
  | "bestie";

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


/**
 * Mengambil preferensi persona AI user dari database.
 * Jika tidak ditemukan atau terjadi error, akan mengembalikan nilai default 'friendly'.
 *
 * @param {string} userId - ID unik dari pengguna (UID).
 * @return {Promise<PersonaType>} Promise yang berisi tipe persona.
 */
async function getUserPersona(userId: string): Promise<PersonaType> {
  try {
    const doc = await db.collection("users").doc(userId).get();
    const p = doc.data()?.aiPersona as PersonaType;
    if (
      p &&
      ["formal", "tough", "friendly", "coach", "motherly", "bestie"].includes(p)
    ) {
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
    if (
      !data?.journal ||
      (data.mood !== "Menunggu AI..." && data.mood !== null)
    ) {
      return;
    }

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
      const detected = result.response.text().trim();

      const valid = [
        "Sangat Baik",
        "Baik",
        "Biasa Saja",
        "Buruk",
        "Sangat Buruk",
      ];
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

    const moodReset =
      after.mood === "Menunggu AI..." && before.mood !== "Menunggu AI...";
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
      const detected = result.response.text().trim();

      const valid = [
        "Sangat Baik",
        "Baik",
        "Biasa Saja",
        "Buruk",
        "Sangat Buruk",
      ];
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
    if (!data?.mood || !data?.journal || !data?.userId || data.reflection)
      return;

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
    const prompt = PERSONA_PROMPTS_REFLECTION[persona](
      after.mood,
      after.journal
    );

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

/* ==================== DAILY SUMMARY 7 HARI  ================= */

export const generateDailySummary = onDocumentCreated(
  {
    document: "mood_entries/{entryId}",
    region: "asia-southeast2",
    secrets: ["GEMINI_API_KEY"],
    timeoutSeconds: 180,
    memory: "512MiB",
    cpu: 1,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const data = snapshot.data();
    if (!data?.userId) return;

    const userId = data.userId;

    try {
      // 1. Ambil persona user
      const persona = await getUserPersona(userId);

      // 2. Ambil semua entry 7 hari terakhir
      const sevenDaysAgo = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
      );

      const entriesSnap = await db
        .collection("mood_entries")
        .where("userId", "==", userId)
        .where("timestamp", ">=", sevenDaysAgo)
        .orderBy("timestamp", "desc")
        .get();

      if (entriesSnap.empty || entriesSnap.size < 2) {
        const shortMsgByPersona: Record<PersonaType, string> = {
          formal: "Anda baru memulai pencatatan mood. Konsistensi adalah kunci perbaikan diri.",
          tough: "Baru mulai? Jangan cuma nulis, langsung action. Mulai hari ini lebih serius.",
          friendly: "Yeay, kamu udah mulai nulis perasaanmu! Keren banget, lanjut terus ya sayang!",
          coach: "Langkah pertama sudah diambil! Sekarang gaspol konsisten tiap hari!",
          motherly: "Nak, kamu sudah mulai menulis perasaanmu. Mama bangga banget sama kamu.",
          bestie: "Akhirnya lu mulai nulis juga wkwk! Gas lah bro, jangan berhenti!",
        };

        await db
          .collection("users")
          .doc(userId)
          .collection("summary")
          .doc("daily")
          .set(
            {
              recommendation: shortMsgByPersona[persona],
              generatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        return;
      }

      // 3. Kumpulkan jurnal jadi satu teks
      const journalsText = entriesSnap.docs
        .map((doc) => {
          const d = doc.data();
          const date = d.timestamp?.toDate().toLocaleDateString("id-ID", {
            day: "numeric",
            month: "short",
          });
          const mood = d.mood || "Biasa Saja";
          const journal = (d.journal || "").trim();
          return journal ? `${date} (${mood}): ${journal}` : null;
        })
        .filter(Boolean)
        .join("\n\n");

      // 4. Prompt khusus per persona
      const personaPrompts: Record<PersonaType, string> = {
        formal: `Anda adalah konsultan profesional. Rangkum pola emosi 7 hari ini secara objektif dalam 2 kalimat, lalu berikan 1 saran singkat yang actionable. Gunakan bahasa baku dan panggil "Anda". Maksimal 3 kalimat total.`,

        tough: `Kamu mentor keras. Bilang apa adanya pola emosinya minggu ini, terus kasih 1 perintah tegas yang harus dilakukan mulai hari ini. Maksimal 2–3 kalimat, tanpa basa-basi.`,

        friendly: `Kamu sahabat dekat yang hangat. Bilang kamu ngerti banget perjalanannya minggu ini, kasih dukungan, lalu saranin 1 hal kecil yang bisa dilakukan hari ini. Boleh pakai "sayang", "aku ada buat kamu".`,

        coach: `Kamu life coach penuh energi! Bilang "Minggu ini kamu udah..." lalu puji pencapaiannya, terus kasih 1 tantangan kecil buat hari ini dengan semangat tinggi: "Gaspol!", "Come on!", "Kamu bisa!".`,

        motherly: `Kamu mama yang penuh kasih. Panggil "nak" atau "sayang", bilang mama lihat perjuangannya, terus kasih 1 nasihat lembut tapi tegas untuk hari ini.`,

        bestie: `Kamu bestie gaul abis. Pakai bahasa anak Jaksel, santai, relate banget. Bilang "gila lu minggu ini...", terus kasih saran santai tapi ngena. Maksimal 3 kalimat.`,
      };

      const PROMPT = `
${personaPrompts[persona]}

Ini semua jurnal user 7 hari terakhir:
${journalsText}

Berikan pesan singkat (maksimal 3 kalimat) sesuai gaya persona di atas. Langsung mulai pesan, tanpa pengantar.
`;

      const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
      if (!GEMINI_API_KEY) return;

      const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
      const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
      const result = await model.generateContent(PROMPT);
      let recommendation = result.response.text().trim();

      // Fallback sesuai persona kalau AI ngaco
      if (!recommendation || recommendation.length > 220) {
        const fallback: Record<PersonaType, string> = {
          formal: "Minggu ini Anda mengalami fluktuasi emosi yang cukup signifikan. Mulailah hari dengan rutinitas pagi yang terstruktur untuk meningkatkan stabilitas.",
          tough: "Masih naik-turun emosinya. Besok bangun jam 5, olahraga, dan jangan buka HP sebelum jam 8. Titik.",
          friendly: "Minggu ini berat ya sayang, tapi kamu tetap nulis tiap hari — aku bangga banget. Besok coba peluk diri sendiri dulu ya, kamu layak dicintai.",
          coach: "Kamu udah bertahan 7 hari penuh! Besok kita level up — 20 menit olahraga pagi, no excuse! You got this!",
          motherly: "Nak, mama lihat kamu sudah berjuang banget. Besok istirahat cukup ya, jangan paksain. Mama ada di sini.",
          bestie: "Gila lu minggu ini drama banget wkwk. Besok matiin notif sosmed 1 hari aja, chill dulu bro. Lu kuat kok!",
        };
        recommendation = fallback[persona];
      }

      // Simpan
      await db
        .collection("users")
        .doc(userId)
        .collection("summary")
        .doc("daily")
        .set(
          {
            recommendation,
            generatedAt: admin.firestore.FieldValue.serverTimestamp(),
            entryCount: entriesSnap.size,
          },
          { merge: true }
        );

    } catch (error: any) {
      logger.error("generateDailySummary error:", error);
    }
  }
);

/* ==================== AUTO UPDATE SUMMARY KETIKA GANTI PERSONA ================= */

export const updateSummaryOnPersonaChange = onDocumentUpdated(
  {
    document: "users/{userId}",
    region: "asia-southeast2",
    secrets: ["GEMINI_API_KEY"],
    timeoutSeconds: 180,
    memory: "512MiB",
    cpu: 1,
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const userId = event.params.userId;

    if (!before || !after || !userId) return;

    // Cek apakah field aiPersona berubah
    const oldPersona = before.aiPersona as PersonaType | undefined;
    const newPersona = after.aiPersona as PersonaType | undefined;

    if (oldPersona === newPersona || !newPersona) return;

    logger.info(`Persona berubah dari ${oldPersona} → ${newPersona} untuk user ${userId}. Memicu update summary...`);

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

      // Kalau belum ada cukup entry, kasih pesan sesuai persona baru
      if (entriesSnap.empty || entriesSnap.size < 2) {
        const shortMsgByPersona: Record<PersonaType, string> = {
          formal: "Anda baru memulai pencatatan mood. Konsistensi adalah kunci perbaikan diri.",
          tough: "Baru mulai? Jangan cuma nulis, langsung action. Mulai hari ini lebih serius.",
          friendly: "Yeay, kamu udah mulai nulis perasaanmu! Keren banget, lanjut terus ya sayang!",
          coach: "Langkah pertama sudah diambil! Sekarang gaspol konsisten tiap hari!",
          motherly: "Nak, kamu sudah mulai menulis perasaanmu. Mama bangga banget sama kamu.",
          bestie: "Akhirnya lu mulai nulis juga wkwk! Gas lah bro, jangan berhenti!",
        };

        await db
          .collection("users")
          .doc(userId)
          .collection("summary")
          .doc("daily")
          .set(
            {
              recommendation: shortMsgByPersona[newPersona],
              generatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        return;
      }

      // Kumpulkan jurnal
      const journalsText = entriesSnap.docs
        .map((doc) => {
          const d = doc.data();
          const date = d.timestamp?.toDate().toLocaleDateString("id-ID", {
            day: "numeric",
            month: "short",
          });
          const mood = d.mood || "Biasa Saja";
          const journal = (d.journal || "").trim();
          return journal ? `${date} (${mood}): ${journal}` : null;
        })
        .filter(Boolean)
        .join("\n\n");

      // Prompt sesuai persona baru
      const personaPrompts: Record<PersonaType, string> = {
        formal: `Anda adalah konsultan profesional. Rangkum pola emosi 7 hari ini secara objektif dalam 2 kalimat, lalu berikan 1 saran singkat yang actionable. Gunakan bahasa baku dan panggil "Anda". Maksimal 3 kalimat total.`,

        tough: `Kamu mentor keras. Bilang apa adanya pola emosinya minggu ini, terus kasih 1 perintah tegas yang harus dilakukan mulai hari ini. Maksimal 2–3 kalimat, tanpa basa-basi.`,

        friendly: `Kamu sahabat dekat yang hangat. Bilang kamu ngerti banget perjalanannya minggu ini, kasih dukungan, lalu saranin 1 hal kecil yang bisa dilakukan hari ini. Boleh pakai "sayang", "aku ada buat kamu".`,

        coach: `Kamu life coach penuh energi! Bilang "Minggu ini kamu udah..." lalu puji pencapaiannya, terus kasih 1 tantangan kecil buat hari ini dengan semangat tinggi: "Gaspol!", "Come on!", "Kamu bisa!".`,

        motherly: `Kamu mama yang penuh kasih. Panggil "nak" atau "sayang", bilang mama lihat perjuangannya, terus kasih 1 nasihat lembut tapi tegas untuk hari ini.`,

        bestie: `Kamu bestie gaul abis. Pakai bahasa anak Jaksel, santai, relate banget. Bilang "gila lu minggu ini...", terus kasih saran santai tapi ngena. Maksimal 3 kalimat.`,
      };

      const PROMPT = `
${personaPrompts[newPersona]}

Ini semua jurnal user 7 hari terakhir:
${journalsText}

Berikan pesan singkat (maksimal 3 kalimat) sesuai gaya persona di atas. Langsung mulai pesan, tanpa pengantar.
`;

      const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
      if (!GEMINI_API_KEY) return;

      const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
      const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
      const result = await model.generateContent(PROMPT);
      let recommendation = result.response.text().trim();

      // Fallback sesuai persona
      if (!recommendation || recommendation.length > 220) {
        const fallback: Record<PersonaType, string> = {
          formal: "Minggu ini Anda mengalami fluktuasi emosi yang cukup signifikan. Mulailah hari dengan rutinitas pagi yang terstruktur untuk meningkatkan stabilitas.",
          tough: "Masih naik-turun emosinya. Besok bangun jam 5, olahraga, dan jangan buka HP sebelum jam 8. Titik.",
          friendly: "Minggu ini berat ya sayang, tapi kamu tetap nulis tiap hari — aku bangga banget. Besok coba peluk diri sendiri dulu ya, kamu layak dicintai.",
          coach: "Kamu udah bertahan 7 hari penuh! Besok kita level up — 20 menit olahraga pagi, no excuse! You got this!",
          motherly: "Nak, mama lihat kamu sudah berjuang banget. Besok istirahat cukup ya, jangan paksain. Mama ada di sini.",
          bestie: "Gila lu minggu ini drama banget wkwk. Besok matiin notif sosmed 1 hari aja, chill dulu bro. Lu kuat kok!",
        };
        recommendation = fallback[newPersona];
      }

      // Update summary langsung
      await db
        .collection("users")
        .doc(userId)
        .collection("summary")
        .doc("daily")
        .set(
          {
            recommendation,
            generatedAt: admin.firestore.FieldValue.serverTimestamp(),
            entryCount: entriesSnap.size,
          },
          { merge: true }
        );

      logger.info(`Summary berhasil diupdate otomatis untuk user ${userId} dengan persona ${newPersona}`);

    } catch (error: any) {
      logger.error("Error update summary on persona change:", error);
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

type TimestampRange = {
  start: admin.firestore.Timestamp;
  end: admin.firestore.Timestamp;
};

/**
 * Membuat rentang waktu (awal dan akhir hari) berdasarkan tanggal yang diberikan.
 *
 * @param {string} dateString - String tanggal yang akan diproses.
 * @return {TimestampRange} Objek berisi timestamp awal dan akhir hari.
 */
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
    if (!userId || !dateString)
      throw new HttpsError("invalid-argument", "Data tidak lengkap.");

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
      const result = await model.generateContent(
        SYSTEM_PROMPT_DAILY_REFLECTION(journals)
      );
      const text = result.response.text().trim();

      let summary: string[] = [];
      let motivation = "Terus semangat!";

      try {
        const cleaned = text.replace(/```json|```/g, "").trim();
        const json = JSON.parse(cleaned);
        summary = Array.isArray(json.summary) ? json.summary.slice(0, 5) : [];
        motivation = json.motivation || motivation;
      } catch {
        summary = journals
          .split("\n---\n")
          .slice(0, 5)
          .map((s) => s.substring(0, 120));
      }

      return { summary, motivation };
    } catch (e: any) {
      logger.error("getDailyReflection error:", e);
      throw new HttpsError("internal", "Gagal proses AI.");
    }
  }
);

/* ========================== CHATBOT  ========================== */

const PERSONA_CHAT_PROMPTS: Record<PersonaType, string> = {
  formal: `
Kamu adalah konsultan psikologi profesional yang sopan dan terstruktur.
Gunakan bahasa baku, panggil user dengan "Anda", berikan respons yang objektif dan bijaksana.
Balas singkat (1–3 kalimat), empati tapi tetap profesional. JANGAN pakai emoji atau bahasa gaul.
`,

  tough: `
Kamu adalah mentor keras yang tegas dan disiplin (tough love). Tidak ada alasan diterima.
Gunakan bahasa tegas, blak-blakan, langsung ke inti. Dorong user untuk berubah SEKARANG.
Balas maksimal 2 kalimat, tanpa kata manis atau empati berlebih. JANGAN pakai emoji.
`,

  friendly: `
Kamu adalah sahabat dekat yang hangat, suportif, dan selalu ada buat user.
Gunakan bahasa Indonesia santai, boleh pakai "sayang", "gapapa kok", "aku ngerti banget".
Balas penuh empati dan dukungan, 1–3 kalimat. Boleh pakai emoji secukupnya.
`,

  coach: `
Kamu adalah life coach energik dan super motivator!
Gunakan bahasa penuh semangat: "Gaspol!", "Come on!", "Kamu bisa banget!", "Ini waktunya!".
Balas dengan energi tinggi, dorong user untuk action besar. Maksimal 3 kalimat.
`,

  motherly: `
Kamu adalah sosok ibu yang penuh kasih, mengayomi, dan bijaksana.
Panggil user "nak" atau "sayang", gunakan kalimat menenangkan dan penuh kasih sayang.
Contoh: "Peluk mama dulu ya", "Mama tahu kamu lagi susah", "Istirahat dulu nak".
Balas lembut, hangat, maksimal 3 kalimat.
`,

  bestie: `
Kamu adalah bestie gaul yang santai abis, lucu, dan selalu relate!
Gunakan bahasa anak Jaksel kekinian: "gila", "wkwkwk", "duh", "serius lu?", "gas lah bro", "yakin gitu?".
Balas santai, nge-roast dikit boleh, tapi tetep suportif. Maksimal 3 kalimat.
`,
};

export const sendChatMessage = onCall(
  {
    region: "asia-southeast2",
    secrets: ["GEMINI_API_KEY"],
    timeoutSeconds: 90,
    memory: "1GiB",
  },
  async (request) => {
    const { userId, message, chatId } = request.data;
    if (!userId || !message)
      throw new HttpsError("invalid-argument", "Missing data");

    const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
    if (!GEMINI_API_KEY) throw new HttpsError("internal", "API Key missing");

    try {
      // === 1. Ambil persona user ===
      const persona = await getUserPersona(userId);

      // === 2. Setup session chat ===
      let sessionRef;
      if (chatId) {
        sessionRef = db
          .collection("users")
          .doc(userId)
          .collection("chats")
          .doc(chatId);
        if (!(await sessionRef.get()).exists)
          throw new HttpsError("not-found", "Chat not found");
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
          personaAtStart: persona, // simpan persona saat sesi dibuat
        });
      }

      // Simpan pesan user
      await sessionRef.collection("messages").add({
        role: "user",
        message,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      await sessionRef.update({
        lastMessage: admin.firestore.FieldValue.serverTimestamp(),
        messageCount: admin.firestore.FieldValue.increment(1),
      });

      // === 3. Ambil konteks chat (summary + 5 pesan terakhir) ===
      const sessionData = (await sessionRef.get()).data();
      const currentSummary = sessionData?.summary || "Percakapan baru dimulai.";

      const recentMessages = await sessionRef
        .collection("messages")
        .orderBy("timestamp", "desc")
        .limit(10)
        .get();

      const chatHistory = recentMessages.docs
        .reverse()
        .map((doc) => {
          const data = doc.data();
          return `${data.role === "user" ? "User" : "MoodBuddy"}: ${
            data.message
          }`;
        })
        .join("\n");

      // === 4. Bangun prompt sesuai persona ===
      const basePrompt = PERSONA_CHAT_PROMPTS[persona];

      const finalPrompt = `
${basePrompt}

Konteks percakapan sebelumnya:
"${currentSummary}"

Riwayat pesan terbaru:
${chatHistory}

Pesan user terbaru:
${message}

Balas sesuai persona di atas. Maksimal 3 kalimat. JANGAN ulangi konteks atau memperkenalkan diri.
`;

      // === 5. Generate respons dari Gemini ===
      const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
      const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
      const result = await model.generateContent(finalPrompt);
      let reply = result.response.text().trim();

      // Fallback kalau kosong
      if (!reply) reply = "Aku dengerin kok...";

      // === 6. Simpan respons AI ===
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
      throw new HttpsError("internal", "Gagal mengirim pesan: " + e.message);
    }
  }
);

/* ======================= CLEANUP & ETC ======================= */

/**
 * Menghapus seluruh dokumen di dalam sebuah koleksi Firestore secara bertahap.
 *
 * @param {admin.firestore.CollectionReference} collectionRef - Referensi koleksi.
 * @param {number} [batchSize=500] - Jumlah dokumen per batch (opsional, default 500).
 * @return {Promise<void>} Promise yang selesai saat penghapusan tuntas.
 */
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
