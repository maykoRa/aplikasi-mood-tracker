// functions/src/index.ts
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import * as admin from 'firebase-admin';
import { GoogleGenerativeAI } from '@google/generative-ai';

admin.initializeApp();

// === FUNCTION 1: Rekomendasi per entri (SUDAH ADA) ===
const SYSTEM_PROMPT_PER_ENTRY = (mood: string, journal: string) => `
Kamu adalah psikolog ramah bernama "MoodBuddy". 
Analisis mood: "${mood}" dan jurnal: "${journal}".
Berikan 1 rekomendasi singkat (maks 2 kalimat) yang actionable, positif, dan sesuai mood.
Gunakan bahasa Indonesia santai. JANGAN gunakan emoji.
`;

export const generateRecommendation = onDocumentCreated(
  {
    document: 'mood_entries/{entryId}',
    region: 'asia-southeast2',
    secrets: ['GEMINI_API_KEY'],
    timeoutSeconds: 300,
    memory: '512MiB',
    cpu: 1,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    if (!data?.mood || !data?.journal || !data?.userId) return;

    const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
    if (!GEMINI_API_KEY) {
      await snapshot.ref.update({ recommendation: 'Error: API Key hilang.' });
      return;
    }

    let text = null;
    let errorMsg = '';
    let retryCount = 0;
    const maxRetries = 2;

    while (!text && retryCount < maxRetries) {
      try {
        const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
        const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

        const result = await model.generateContent(SYSTEM_PROMPT_PER_ENTRY(data.mood, data.journal));
        text = result.response.text();
        break;
      } catch (error: any) {
        errorMsg = error.message || 'Unknown error';
        if (errorMsg.includes('429')) {
          await new Promise(r => setTimeout(r, 30000));
          retryCount++;
        } else break;
      }
    }

    if (text) {
      await snapshot.ref.update({
        recommendation: text.trim(),
        recommendedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      await snapshot.ref.update({
        recommendation: 'Maaf, AI sedang sibuk. Coba lagi nanti.',
        errorLog: errorMsg.substring(0, 500),
      });
    }
  }
);

// === FUNCTION 2: Rekomendasi Keseluruhan (BARU!) ===
const SYSTEM_PROMPT_SUMMARY = (journal: string) => `
Kamu adalah psikolog ramah bernama "MoodBuddy".
Berikut adalah Simpulkan semua entri mood dan jurnal user dalam 7 hari terakhir:

${journal}

Analisis pola mood, emosi, dan kebiasaan user.
Berikan 1 rekomendasi utama hari ini (maks 3 kalimat) yang:
- Sangat personal & relevan
- Actionable
- Positif & mendukung
- Bahasa Indonesia santai
- JANGAN gunakan emoji
`;

export const generateDailySummary = onDocumentCreated(
  {
    document: 'mood_entries/{entryId}',
    region: 'asia-southeast2',
    secrets: ['GEMINI_API_KEY'],
    timeoutSeconds: 300,
    memory: '1GiB',
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
      const sevenDaysAgo = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
      );

      const entriesSnap = await db
        .collection('mood_entries')
        .where('userId', '==', userId)
        .where('timestamp', '>=', sevenDaysAgo)
        .orderBy('timestamp', 'desc')
        .get();

      if (entriesSnap.empty) return;

      const entriesText = entriesSnap.docs
        .map(doc => {
          const d = doc.data();
          const date = d.timestamp?.toDate().toLocaleDateString('id-ID') || 'Unknown';
          return `- ${date}: Mood "${d.mood}", Jurnal: "${d.journal}"`;
        })
        .join('\n');

      const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY!);
      const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

      const result = await model.generateContent(SYSTEM_PROMPT_SUMMARY(entriesText));
      const summary = result.response.text().trim();

      await db
        .collection('users')
        .doc(userId)
        .collection('summary')
        .doc('daily')
        .set({
          recommendation: summary,
          generatedAt: admin.firestore.FieldValue.serverTimestamp(),
          periodStart: sevenDaysAgo,
          entryCount: entriesSnap.size,
        }, { merge: true });

      console.log(`Summary generated: ${summary.substring(0, 50)}...`);
    } catch (error: any) {
      console.error('Summary Error:', error.message);
    }
  }
);