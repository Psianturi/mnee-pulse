import { GoogleGenerativeAI } from '@google/generative-ai';

export type ContentScore = {
  score: number; // 1-10
  summary: string;
  reason: string;
  isQualified: boolean; // score >= 7
};

let genAI: GoogleGenerativeAI | null = null;

function getClient(): GoogleGenerativeAI {
  if (genAI) return genAI;

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) throw new Error('GEMINI_API_KEY is not set');

  genAI = new GoogleGenerativeAI(apiKey);
  return genAI;
}

const SCORING_PROMPT = `You are an AI content quality evaluator for a micro-tipping platform called MNEE-Pulse.

Evaluate the following content and provide a quality score from 1-10 based on these criteria:
- Originality and creativity (1-3 points)
- Value to community (1-3 points)  
- Effort and quality (1-2 points)
- Engagement potential (1-2 points)

Content to evaluate:
"""
{CONTENT}
"""

Respond in this exact JSON format only, no other text:
{
  "score": <number 1-10>,
  "summary": "<brief 10-word summary of content>",
  "reason": "<1 sentence why this score>"
}`;

export async function scoreContent(content: string): Promise<ContentScore> {
  if (!process.env.GEMINI_API_KEY) {
    // Return mock score for demo when no API key
    return {
      score: 8,
      summary: 'Demo content evaluation',
      reason: 'Gemini API key not configured - using demo score',
      isQualified: true,
    };
  }

  try {
    const client = getClient();
    const model = client.getGenerativeModel({ model: 'gemini-1.5-flash' });

    const prompt = SCORING_PROMPT.replace('{CONTENT}', content.slice(0, 2000));
    const result = await model.generateContent(prompt);
    const response = result.response;
    const text = response.text();

    // Parse JSON from response
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      throw new Error('No JSON found in response');
    }

    const parsed = JSON.parse(jsonMatch[0]);
    const score = Math.min(10, Math.max(1, Number(parsed.score) || 5));

    return {
      score,
      summary: String(parsed.summary || 'Content evaluated'),
      reason: String(parsed.reason || 'AI evaluation complete'),
      isQualified: score >= 7,
    };
  } catch (e) {
    console.error('[gemini] scoring failed:', e);

    return {
      score: 6,
      summary: 'Evaluation pending',
      reason: 'AI temporarily unavailable - default score applied',
      isQualified: false,
    };
  }
}

export async function checkGeminiStatus(): Promise<{
  available: boolean;
  model?: string;
  error?: string;
}> {
  if (!process.env.GEMINI_API_KEY) {
    return { available: false, error: 'GEMINI_API_KEY not set' };
  }

  try {
    const client = getClient();
    const model = client.getGenerativeModel({ model: 'gemini-1.5-flash' });
    const result = await model.generateContent('Say "OK" only');
    const text = result.response.text();
    return { available: text.length > 0, model: 'gemini-1.5-flash' };
  } catch (e) {
    return { available: false, error: (e as Error).message };
  }
}
