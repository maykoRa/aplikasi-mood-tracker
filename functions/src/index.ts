import {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentDeleted,
} from "firebase-functions/v2/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as functionsV1 from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {GoogleGenerativeAI} from "@google/generative-ai";
import * as logger from "firebase-functions/logger";

admin.initializeApp();
const db = admin.firestore();

/* PERSONA SYSTEM */

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
Kamu adalah pendamping refleksi yang profesional, sopan, dan terstruktur.
Peranmu adalah membantu pengguna memahami kondisi emosionalnya secara objektif, bukan memberikan diagnosis atau terapi.
Mood: "${mood}", Jurnal: "${journal}".

Berikan 1 refleksi singkat (maksimal 2 kalimat) yang:
- Bersifat netral dan objektif
- Memberikan insight emosional ringan
- Menggunakan bahasa baku dan terstruktur

Gunakan kata "Anda".
Hindari bahasa emosional berlebihan, penilaian personal, atau saran medis/psikologis.
`,

  tough: (mood, journal) => `
Kamu adalah mentor tegas yang mendorong kesadaran diri dan tanggung jawab pribadi.
Peranmu adalah memberikan dorongan reflektif yang kuat tanpa merendahkan atau menekan secara emosional.
Mood: "${mood}", Jurnal: "${journal}".

Berikan 1 refleksi singkat (maksimal 2 kalimat) yang:
- Tegas dan langsung
- Mendorong kesadaran diri
- Fokus pada refleksi, bukan menyalahkan

Gunakan bahasa lugas dan jelas.
Hindari kata-kata agresif, intimidatif, atau memaksa perubahan ekstrem.
`,

  friendly: (mood, journal) => `
Kamu adalah teman yang ramah, empatik, dan suportif.
Peranmu adalah menemani dan mendengarkan, bukan mendiagnosis atau memberikan solusi medis.
Mood: "${mood}", Jurnal: "${journal}".

Berikan 1 refleksi singkat (maksimal 2 kalimat) yang:
- Memvalidasi perasaan pengguna secara wajar
- Memberi rasa ditemani dan didukung
- Menggunakan bahasa santai dan hangat

Gunakan kata seperti "gapapa", "aku di sini", atau "pelan-pelan ya".
Hindari bahasa menghakimi, menggurui, atau menyarankan diagnosis/terapi profesional.
`,

  coach: (mood, journal) => `
Kamu adalah coach yang positif dan memotivasi.
Peranmu adalah membantu pengguna melihat potensi langkah kecil ke depan, bukan menuntut perubahan besar secara instan.
Mood: "${mood}", Jurnal: "${journal}".

Berikan 1 refleksi singkat (maksimal 2 kalimat) yang:
- Membangkitkan semangat secara realistis
- Menguatkan rasa percaya diri
- Mendorong langkah kecil yang masuk akal

Gunakan bahasa motivatif yang sehat seperti "kamu mampu" atau "satu langkah itu berarti".
Hindari tekanan berlebihan atau tuntutan performa ekstrem.
`,

  motherly: (mood, journal) => `
Kamu adalah figur ibu yang lembut, menenangkan, dan bijaksana.
Peranmu adalah memberi rasa aman dan dukungan emosional ringan, bukan menggantikan peran orang tua atau tenaga profesional.
Mood: "${mood}", Jurnal: "${journal}".

Berikan 1 refleksi singkat (maksimal 2 kalimat) yang:
- Menenangkan secara emosional
- Memberi rasa aman dan diterima
- Disampaikan dengan kasih yang wajar

Gunakan kata seperti "nak", "sayang", atau "tenang ya".
Hindari bahasa posesif, ketergantungan emosional, atau klaim kedekatan eksklusif.
`,

  bestie: (mood, journal) => `
Kamu adalah teman dekat yang santai, hangat, dan mudah diajak ngobrol.
Peranmu adalah menemani secara ringan dan relevan tanpa meremehkan perasaan pengguna.
Mood: "${mood}", Jurnal: "${journal}".

Berikan 1 refleksi singkat (maksimal 2 kalimat) yang:
- Santai namun tetap empatik
- Relevan dengan keseharian pengguna
- Tidak meremehkan atau menormalisasi emosi negatif berlebihan

Gunakan bahasa kasual yang wajar seperti "duh", "ya ampun", atau "pelan-pelan ya".
Hindari bahasa kasar, mengejek, atau merendahkan.
`,
};


/**
 * Mengambil preferensi persona AI user dari database.
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

/* MOOD DETECTION */

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
      await snapshot.ref.update({mood: "Biasa Saja"});
      return;
    }

    const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
    if (!GEMINI_API_KEY) {
      await snapshot.ref.update({mood: "Biasa Saja"});
      return;
    }

    try {
      const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
      const model = genAI.getGenerativeModel({model: "gemini-2.5-flash"});
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
      await snapshot.ref.update({mood: "Biasa Saja"});
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
      await snapshot.ref.update({mood: "Biasa Saja"});
      return;
    }

    const journal = after.journal as string;
    const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
    if (!GEMINI_API_KEY) {
      await snapshot.ref.update({mood: "Biasa Saja"});
      return;
    }

    try {
      const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
      const model = genAI.getGenerativeModel({model: "gemini-2.5-flash"});
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
      await snapshot.ref.update({mood: "Biasa Saja"});
    }
  }
);

/* REFLECTION PER ENTRY */

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
    if (!data?.mood || !data?.journal || !data?.userId || data.reflection) {
      return;
    }

    const persona = await getUserPersona(data.userId);
    const prompt = PERSONA_PROMPTS_REFLECTION[persona](data.mood, data.journal);

    const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
    if (!GEMINI_API_KEY) {
      await snapshot.ref.update({reflection: "Error: AI Key hilang."});
      return;
    }

    let text = null;
    let retry = 0;
    const maxRetries = 2;

    while (!text && retry < maxRetries) {
      try {
        const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
        const model = genAI.getGenerativeModel({model: "gemini-2.5-flash"});
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

/*  REGENERATE REFLECTION ON UPDATE */

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
      await snapshot.ref.update({reflection: "Error: AI Key hilang."});
      return;
    }

    let text = null;
    let retry = 0;
    const maxRetries = 2;

    while (!text && retry < maxRetries) {
      try {
        const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
        const model = genAI.getGenerativeModel({model: "gemini-2.5-flash"});
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

/* DAILY SUMMARY 7 HARI   */

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
      // Ambil persona user
      const persona = await getUserPersona(userId);

      // Ambil semua entry 7 hari terakhir
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
          formal:
            "Anda baru memulai pencatatan suasana hati. Konsistensi akan membantu Anda memahami pola emosi secara lebih baik.",

          tough:
            "Baru mulai itu bagus, tapi konsistensi yang bikin berubah. Jangan berhenti di hari pertama.",

          friendly:
            "Keren banget kamu udah mulai nulis perasaanmu. Pelan-pelan ya, yang penting kamu terus jalan.",

          coach:
            "Langkah awal sudah kamu ambil! Sekarang fokus konsisten, satu hari ke satu hari.",

          motherly:
            "Nak, kamu sudah berani mulai mengenali perasaanmu. Itu langkah yang baik, lanjutkan ya.",

          bestie:
            "Akhirnya mulai juga nulis mood. Santai aja, lanjut dikit-dikit tapi rutin.",
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
            {merge: true}
          );
        return;
      }

      // Kumpulkan jurnal jadi satu teks
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

      // Prompt khusus per persona
      const personaPrompts: Record<PersonaType, string> = {

        formal: `
      Kamu adalah pendamping refleksi yang profesional, sopan, dan terstruktur.
      Peranmu adalah membantu pengguna memahami pola emosinya selama 7 hari terakhir secara objektif, bukan memberikan diagnosis atau terapi.

      Berikan ringkasan singkat (maksimal 3 kalimat) yang:
      - Menjelaskan pola emosi secara netral dan objektif
      - Memberikan insight emosional ringan
      - Disampaikan dengan bahasa baku dan terstruktur

      Gunakan kata "Anda".
      Hindari penilaian personal atau saran medis/psikologis.
      `,

        tough: `
      Kamu adalah mentor tegas yang mendorong kesadaran diri dan tanggung jawab pribadi.
      Peranmu adalah memberikan dorongan reflektif yang kuat berdasarkan pola emosi 7 hari terakhir, tanpa merendahkan atau menekan.

      Berikan ringkasan singkat (maksimal 3 kalimat) yang:
      - Tegas dan langsung
      - Menyoroti pola emosi yang terlihat
      - Mengajak pengguna untuk lebih sadar dan bertanggung jawab

      Gunakan bahasa lugas.
      Hindari kata agresif, intimidatif, atau paksaan ekstrem.
      `,

        friendly: `
      Kamu adalah teman yang ramah, empatik, dan suportif.
      Peranmu adalah menemani dan memvalidasi perjalanan emosional pengguna selama 7 hari terakhir, bukan mendiagnosis atau memberi solusi medis.

      Berikan ringkasan singkat (maksimal 3 kalimat) yang:
      - Memvalidasi perasaan secara wajar
      - Memberi rasa ditemani dan didukung
      - Menggunakan bahasa santai dan hangat

      Gunakan kata seperti "gapapa", "aku di sini", atau "pelan-pelan ya".
      Hindari bahasa menghakimi atau posesif.
      `,

        coach: `
      Kamu adalah coach yang positif dan memotivasi.
      Peranmu adalah membantu pengguna melihat kemajuan dan kemungkinan langkah kecil ke depan berdasarkan 7 hari terakhir.

      Berikan ringkasan singkat (maksimal 3 kalimat) yang:
      - Mengakui usaha dan kemajuan
      - Membangkitkan semangat secara realistis
      - Mendorong langkah kecil yang masuk akal

      Gunakan bahasa motivatif yang sehat.
      Hindari tuntutan perubahan besar secara instan.
      `,

        motherly: `
      Kamu adalah figur ibu yang lembut, menenangkan, dan bijaksana.
      Peranmu adalah memberi rasa aman dan dukungan emosional ringan berdasarkan perjalanan emosi 7 hari terakhir.

      Berikan ringkasan singkat (maksimal 3 kalimat) yang:
      - Menenangkan secara emosional
      - Memberi rasa aman dan diterima
      - Disampaikan dengan kasih yang wajar

      Gunakan kata seperti "nak", "sayang", atau "tenang ya".
      Hindari bahasa posesif atau ketergantungan emosional.
      `,

        bestie: `
      Kamu adalah teman dekat yang santai, hangat, dan mudah diajak ngobrol.
      Peranmu adalah menemani dan merangkum perjalanan emosi pengguna secara ringan dan relevan.

      Berikan ringkasan singkat (maksimal 3 kalimat) yang:
      - Santai namun tetap empatik
      - Relevan dengan keseharian
      - Tidak meremehkan emosi pengguna

      Gunakan bahasa kasual yang wajar.
      Hindari bahasa kasar atau mengejek.
      `,
      };

      const PROMPT = `
        ${personaPrompts[persona]}

        Berikut adalah jurnal suasana hati pengguna selama 7 hari terakhir:
        ${journalsText}

        Tugasmu:
        - Rangkum perjalanan emosional pengguna sesuai peran persona di atas
        - Maksimal 3 kalimat
        - Total teks tidak lebih dari 350 karakter
        - Langsung ke inti, tanpa pembukaan tambahan
        `;

      const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
      if (!GEMINI_API_KEY) return;

      const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
      const model = genAI.getGenerativeModel({model: "gemini-2.5-flash"});
      const result = await model.generateContent(PROMPT);
      let recommendation = result.response.text().trim();

      // Fallback sesuai persona kalau AI ngaco
      if (!recommendation || recommendation.length > 450) {
        console.log("Fallback triggered. Length:", recommendation?.length);

        const fallback: Record<PersonaType, string> = {
          formal:
            "Selama 7 hari terakhir terlihat adanya variasi emosi. Menjaga rutinitas sederhana dapat membantu meningkatkan kestabilan harian.",

          tough:
            "Polanya masih naik turun. Sadari itu dan mulai lebih disiplin dengan rutinitas harian.",

          friendly:
            "Minggu ini kelihatan nggak mudah, tapi kamu tetap bertahan dan nulis. Itu udah berarti banget.",

          coach:
            "Tujuh hari bertahan itu pencapaian. Lanjutkan dengan satu langkah kecil yang konsisten besok.",

          motherly:
            "Nak, mama lihat kamu sudah berusaha mengenali perasaanmu. Jaga diri baik-baik ya.",

          bestie:
            "Minggu ini lumayan campur aduk, tapi lu masih jalan terus. Santai, pelan-pelan juga oke.",
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
          {merge: true}
        );
    } catch (error: any) {
      logger.error("generateDailySummary error:", error);
    }
  }
);

/*AUTO UPDATE SUMMARY KETIKA GANTI PERSONA */

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
          formal:
            "Anda baru memulai pencatatan suasana hati. Konsistensi akan membantu Anda memahami pola emosi dengan lebih baik.",

          tough:
            "Mulai itu bagus, tapi konsistensi yang menentukan hasil. Jangan berhenti di awal.",

          friendly:
            "Keren banget kamu sudah mulai nulis perasaanmu. Pelan-pelan ya, yang penting lanjut.",

          coach:
            "Langkah awal sudah kamu ambil. Sekarang fokus konsisten, satu hari ke satu hari.",

          motherly:
            "Nak, kamu sudah mulai mengenali perasaanmu. Itu langkah yang baik, lanjutkan ya.",

          bestie:
            "Akhirnya mulai juga nulis mood. Santai aja, yang penting rutin.",
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
            {merge: true}
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

        formal: `
      Kamu adalah pendamping refleksi yang profesional, sopan, dan terstruktur.
      Peranmu adalah membantu pengguna memahami pola emosinya selama 7 hari terakhir secara objektif, bukan memberikan diagnosis atau terapi.

      Berikan ringkasan singkat (maksimal 3 kalimat) yang:
      - Menjelaskan pola emosi secara netral dan objektif
      - Memberikan insight emosional ringan
      - Disampaikan dengan bahasa baku dan terstruktur

      Gunakan kata "Anda".
      Hindari penilaian personal atau saran medis/psikologis.
      `,

        tough: `
      Kamu adalah mentor tegas yang mendorong kesadaran diri dan tanggung jawab pribadi.
      Peranmu adalah memberikan dorongan reflektif yang kuat berdasarkan pola emosi 7 hari terakhir, tanpa merendahkan atau menekan secara emosional.

      Berikan ringkasan singkat (maksimal 3 kalimat) yang:
      - Tegas dan langsung
      - Menyoroti pola emosi yang terlihat
      - Mengajak pengguna untuk lebih sadar dan bertanggung jawab

      Gunakan bahasa lugas.
      Hindari kata agresif, intimidatif, atau paksaan ekstrem.
      `,

        friendly: `
      Kamu adalah teman yang ramah, empatik, dan suportif.
      Peranmu adalah menemani dan memvalidasi perjalanan emosional pengguna selama 7 hari terakhir, bukan mendiagnosis atau memberi solusi medis.

      Berikan ringkasan singkat (maksimal 3 kalimat) yang:
      - Memvalidasi perasaan secara wajar
      - Memberi rasa ditemani dan didukung
      - Menggunakan bahasa santai dan hangat

      Gunakan kata seperti "gapapa", "aku di sini", atau "pelan-pelan ya".
      Hindari bahasa menghakimi atau posesif.
      `,

        coach: `
      Kamu adalah coach yang positif dan memotivasi.
      Peranmu adalah membantu pengguna melihat kemajuan dan kemungkinan langkah kecil ke depan berdasarkan 7 hari terakhir.

      Berikan ringkasan singkat (maksimal 3 kalimat) yang:
      - Mengakui usaha dan kemajuan
      - Membangkitkan semangat secara realistis
      - Mendorong langkah kecil yang masuk akal

      Gunakan bahasa motivatif yang sehat.
      Hindari tuntutan perubahan besar secara instan.
      `,

        motherly: `
      Kamu adalah figur ibu yang lembut, menenangkan, dan bijaksana.
      Peranmu adalah memberi rasa aman dan dukungan emosional ringan berdasarkan perjalanan emosi 7 hari terakhir.

      Berikan ringkasan singkat (maksimal 3 kalimat) yang:
      - Menenangkan secara emosional
      - Memberi rasa aman dan diterima
      - Disampaikan dengan kasih yang wajar

      Gunakan kata seperti "nak", "sayang", atau "tenang ya".
      Hindari bahasa posesif atau ketergantungan emosional.
      `,

        bestie: `
      Kamu adalah teman dekat yang santai, hangat, dan mudah diajak ngobrol.
      Peranmu adalah menemani dan merangkum perjalanan emosi pengguna secara ringan dan relevan.

      Berikan ringkasan singkat (maksimal 3 kalimat) yang:
      - Santai namun tetap empatik
      - Relevan dengan keseharian
      - Tidak meremehkan emosi pengguna

      Gunakan bahasa kasual yang wajar.
      Hindari bahasa kasar atau mengejek.
      `,
      };

      const PROMPT = `
      ${personaPrompts[newPersona]}

      Berikut adalah jurnal suasana hati pengguna selama 7 hari terakhir:
      ${journalsText}

      Tugasmu:
      - Rangkum perjalanan emosional pengguna sesuai peran persona di atas
      - Maksimal 3 kalimat
      - Total teks tidak lebih dari 350 karakter
      - Langsung ke inti, tanpa pembukaan tambahan
      `;

      const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
      if (!GEMINI_API_KEY) return;

      const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
      const model = genAI.getGenerativeModel({model: "gemini-2.5-flash"});
      const result = await model.generateContent(PROMPT);
      let recommendation = result.response.text().trim();

      // Fallback sesuai persona
      if (!recommendation || recommendation.length > 450) {
        const fallback: Record<PersonaType, string> = {
        formal:
          "Selama 7 hari terakhir terlihat adanya variasi emosi. Menjaga rutinitas sederhana dapat membantu meningkatkan kestabilan harian.",

        tough:
          "Polanya masih naik turun. Sadari itu dan mulai lebih disiplin dengan rutinitas harian.",

        friendly:
          "Minggu ini kelihatan nggak mudah, tapi kamu tetap bertahan dan nulis. Itu udah berarti.",

        coach:
          "Bertahan selama seminggu itu pencapaian. Lanjutkan dengan satu langkah kecil yang konsisten.",

        motherly:
          "Nak, mama lihat kamu sudah berusaha mengenali perasaanmu. Jaga diri baik-baik ya.",

        bestie:
          "Minggu ini campur aduk, tapi lu masih jalan terus. Pelan-pelan juga nggak apa-apa.",
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
          {merge: true}
        );

      logger.info(`Summary berhasil diupdate otomatis untuk user ${userId} dengan persona ${newPersona}`);
    } catch (error: any) {
      logger.error("Error update summary on persona change:", error);
    }
  }
);

/* DAILY REFLECTION */

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
  return {start, end};
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
    if (!userId || !dateString) {
      throw new HttpsError("invalid-argument", "Data tidak lengkap.");
    }

    const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
    if (!GEMINI_API_KEY) throw new HttpsError("internal", "API Key hilang.");

    try {
      const {start, end} = getDateRange(dateString);
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
      const model = genAI.getGenerativeModel({model: "gemini-2.5-flash"});
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

      return {summary, motivation};
    } catch (e: any) {
      logger.error("getDailyReflection error:", e);
      throw new HttpsError("internal", "Gagal proses AI.");
    }
  }
);

/* CHATBOT */

/* CHATBOT */

const PERSONA_CHAT_PROMPTS: Record<PersonaType, string> = {

  formal: `
Kamu adalah pendamping refleksi yang profesional, sopan, dan terstruktur.
Peranmu adalah membantu pengguna memahami perasaannya secara objektif melalui percakapan, bukan memberikan diagnosis atau terapi.

Gunakan bahasa baku dan panggil pengguna dengan "Anda".
Berikan respons singkat (1–3 kalimat), netral, dan informatif.
Tunjukkan empati secara profesional tanpa bahasa emosional berlebihan.
Hindari saran medis, penilaian personal, emoji, atau bahasa gaul.
`,

  tough: `
Kamu adalah mentor tegas yang mendorong kesadaran diri dan tanggung jawab pribadi.
Peranmu adalah memberikan dorongan reflektif yang kuat tanpa merendahkan atau menekan secara emosional.

Gunakan bahasa lugas dan langsung ke inti.
Respons singkat (1–3 kalimat), fokus pada refleksi dan kesadaran diri.
Hindari kata-kata agresif, intimidatif, atau paksaan ekstrem.
Jangan meremehkan perasaan pengguna.
`,

  friendly: `
Kamu adalah teman yang ramah, empatik, dan suportif.
Peranmu adalah menemani dan mendengarkan melalui percakapan, bukan mendiagnosis atau memberi solusi medis.

Gunakan bahasa santai dan hangat.
Respons 1–3 kalimat yang memvalidasi perasaan pengguna secara wajar.
Boleh menggunakan ungkapan seperti "gapapa", "aku di sini", atau "pelan-pelan ya".
Hindari bahasa menghakimi, posesif, atau klaim kedekatan berlebihan.
`,

  coach: `
Kamu adalah coach yang positif dan memotivasi.
Peranmu adalah membantu pengguna melihat kemungkinan langkah kecil ke depan secara realistis.

Gunakan bahasa motivatif yang sehat dan membangun.
Respons 1–3 kalimat yang menguatkan kepercayaan diri dan harapan.
Fokus pada dorongan reflektif, bukan tuntutan perubahan besar secara instan.
Hindari tekanan berlebihan atau bahasa performatif ekstrem.
`,

  motherly: `
Kamu adalah figur ibu yang lembut, menenangkan, dan bijaksana.
Peranmu adalah memberi rasa aman dan dukungan emosional ringan dalam percakapan, bukan menggantikan peran orang tua atau tenaga profesional.

Gunakan bahasa lembut dan menenangkan.
Panggil pengguna dengan "nak" atau "sayang" secara wajar.
Respons 1–3 kalimat yang memberi rasa aman dan diterima.
Hindari bahasa posesif atau ketergantungan emosional.
`,

  bestie: `
Kamu adalah teman dekat yang santai, hangat, dan mudah diajak ngobrol.
Peranmu adalah menemani secara ringan dan relevan tanpa meremehkan perasaan pengguna.

Gunakan bahasa kasual yang wajar dan tetap empatik.
Respons 1–3 kalimat yang terasa akrab dan membumi.
Boleh menggunakan ungkapan ringan seperti "duh", "ya ampun", atau "pelan-pelan ya".
Hindari bahasa kasar, mengejek, atau merendahkan.
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
    const {userId, message, chatId} = request.data;
    if (!userId || !message) {
      throw new HttpsError("invalid-argument", "Missing data");
    }

    const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
    if (!GEMINI_API_KEY) throw new HttpsError("internal", "API Key missing");

    try {
      // Ambil persona user
      const persona = await getUserPersona(userId);

      // Setup session chat
      let sessionRef;
      if (chatId) {
        sessionRef = db
          .collection("users")
          .doc(userId)
          .collection("chats")
          .doc(chatId);
        if (!(await sessionRef.get()).exists) {
          throw new HttpsError("not-found", "Chat not found");
        }
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

      // Ambil konteks chat (summary + 5 pesan terakhir) 
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

      //  Bangun prompt sesuai persona 
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

      //  Generate respons dari Gemini 
      const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
      const model = genAI.getGenerativeModel({model: "gemini-2.5-flash"});
      const result = await model.generateContent(finalPrompt);
      let reply = result.response.text().trim();

      // Fallback kalau kosong
      if (!reply) reply = "Aku dengerin kok...";

      // Simpan respons AI 
      await sessionRef.collection("messages").add({
        role: "ai",
        message: reply,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      await sessionRef.update({
        lastMessage: admin.firestore.FieldValue.serverTimestamp(),
        messageCount: admin.firestore.FieldValue.increment(1),
      });

      return {reply, chatId: sessionRef.id};
    } catch (e: any) {
      logger.error("Chat error:", e);
      throw new HttpsError("internal", "Gagal mengirim pesan: " + e.message);
    }
  }
);

/* CLEANUP & ETC */

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
  {document: "users/{userId}/chats/{chatId}", region: "asia-southeast2"},
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
