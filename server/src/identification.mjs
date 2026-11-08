import { createHash } from 'node:crypto';
import { findCatalogSpecies } from './species-catalog.mjs';

function clamp(value) { return Math.max(0, Math.min(1, Number(value) || 0)); }

function dynamicId(item) {
  const source = String(item.scientificName || item.name || 'unknown').trim().toLocaleLowerCase('en-US');
  const readable = source.normalize('NFKD').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 42);
  return `ai-${readable || createHash('sha1').update(source).digest('hex').slice(0, 12)}`;
}

function contextScore(item, request) {
  const place = String(request.placeName || '');
  const regions = Array.isArray(item.regions) ? item.regions : [];
  const matched = regions.some(region => place.includes(region));
  const month = Number(String(request.observedAt || '').slice(5, 7));
  return Math.min(0.18, (month >= 3 && month <= 11 ? 0.06 : 0.03) + (matched ? 0.1 : 0.02));
}

function normalizeCandidate(raw, request) {
  const catalog = findCatalogSpecies(raw);
  const reasons = Array.isArray(raw?.reasons) ? raw.reasons.map(String).filter(Boolean).slice(0, 4) : [];
  const detail = catalog || {
    id: dynamicId(raw), name: String(raw?.name || '中文名待核对').trim(), scientificName: String(raw?.scientificName || '').trim(),
    aliases: [], category: String(raw?.category || '分类待核对').trim(),
    description: String(raw?.description || '该物种暂未收录在离线图鉴中，请结合照片特征人工确认。').trim(),
    regions: [], imageHint: 'unknown', features: reasons
  };
  const modelScore = clamp(raw?.score); const context = contextScore(detail, request);
  return {
    speciesId: detail.id, name: detail.name, scientificName: detail.scientificName, aliases: detail.aliases || [],
    category: detail.category, description: detail.description, regions: detail.regions || [], imageHint: detail.imageHint || 'unknown',
    inCatalog: Boolean(catalog), modelScore, contextScore: context, finalScore: Math.min(0.99, modelScore * 0.88 + context),
    reasons: reasons.length ? reasons : (detail.features || []).slice(0, 4)
  };
}

function normalizeCandidates(raw, request) {
  if (!Array.isArray(raw)) return [];
  const unique = new Map();
  raw.forEach(item => {
    if (!item || (!String(item.name || '').trim() && !String(item.scientificName || '').trim())) return;
    const candidate = normalizeCandidate(item, request); const previous = unique.get(candidate.speciesId);
    if (!previous || previous.finalScore < candidate.finalScore) unique.set(candidate.speciesId, candidate);
  });
  return [...unique.values()].sort((a, b) => b.finalScore - a.finalScore).slice(0, 3);
}

function parseProviderContent(content) {
  const cleaned = String(content || '').trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/i, '').trim();
  const parsed = JSON.parse(cleaned); return Array.isArray(parsed) ? parsed : parsed.candidates;
}

export async function identifyBird(request, env) {
  const configured = Boolean(env.VISION_API_URL?.trim() && env.VISION_API_KEY?.trim() && env.VISION_MODEL?.trim());
  if (!configured) return { mode: 'unavailable', candidates: [], warning: '视觉模型尚未配置，请在设置中检查后端，或前往图鉴手动选择鸟种。' };
  try {
    const response = await fetch(env.VISION_API_URL, {
      method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${env.VISION_API_KEY}` }, signal: AbortSignal.timeout(25000),
      body: JSON.stringify({ model: env.VISION_MODEL, temperature: 0, messages: [{ role: 'user', content: [
        { type: 'text', text: '识别照片中的鸟类，不限物种。返回最多三个合理候选；若不是鸟或无法辨认，返回空数组。仅返回 JSON 数组，不要 Markdown。每项必须包含 name（规范中文名）、scientificName（拉丁学名）、category（中文科名）、score（0到1）、reasons（2到4条从照片可见的中文辨识依据）和 description（一句客观中文简介）。不要为了迎合而猜测。' },
        { type: 'image_url', image_url: { url: request.imageBase64 } }
      ] }] })
    });
    if (!response.ok) throw new Error(`provider ${response.status}`);
    const payload = await response.json();
    const candidates = normalizeCandidates(parseProviderContent(payload?.choices?.[0]?.message?.content), request);
    if (!candidates.length) return { mode: 'provider', candidates: [], warning: '模型未能从照片中确认鸟类，请换一张主体更清晰的照片，或从图鉴手动选择。' };
    const confidence = Number(candidates[0].finalScore || 0);
    const lowConfidence = confidence < 0.55 ? '当前最高候选置信度较低，建议人工复核或从离线图鉴选择。' : '';
    return { mode: 'provider', candidates, warning: `AI 结果仅作为候选，请结合照片、地点和辨识特征确认后再记录。${lowConfidence}` };
  } catch (error) {
    return { mode: 'unavailable', candidates: [], warning: `视觉识别暂不可用（${String(error?.message || 'unknown')}），没有伪造候选。请重试或从图鉴手动选择。` };
  }
}
