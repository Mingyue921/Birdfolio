function providerError(code, status = 0) { const error = new Error(code); error.status = status; return error; }

export function createVisionProvider(env, options = {}) {
  const providerName = String(env.VISION_PROVIDER || 'openai_compatible').trim().toLowerCase();
  const apiUrl = String(env.VISION_API_URL || '').trim();
  const apiKey = String(env.VISION_API_KEY || '').trim();
  const model = String(env.VISION_MODEL || '').trim();
  const fetchImpl = options.fetchImpl || fetch;
  const configured = Boolean(apiUrl && apiKey && model);
  return {
    name: providerName === 'huawei_maas' ? 'huawei_maas' : 'openai_compatible',
    modelVersion: model,
    configured,
    async identify(request) {
      if (!configured) throw providerError('PROVIDER_NOT_CONFIGURED');
      const started = Date.now(); let response;
      try {
        response = await fetchImpl(apiUrl, {
          method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${apiKey}` }, signal: AbortSignal.timeout(Math.max(1000, Number(env.VISION_TIMEOUT_MS || 25000))),
          body: JSON.stringify({ model, temperature: 0, messages: [{ role: 'user', content: [
            { type: 'text', text: '识别照片中的鸟类，不限物种。返回最多三个合理候选；若不是鸟或无法辨认，返回空数组。仅返回 JSON 数组，不要 Markdown。每项必须包含 name（规范中文名）、scientificName（拉丁学名）、category（中文科名）、score（0到1）、reasons（2到4条从照片可见的中文辨识依据）和 description（一句客观中文简介）。不要为了迎合而猜测。' },
            { type: 'image_url', image_url: { url: request.imageBase64 } }
          ] }] })
        });
      } catch (error) {
        if (String(error?.name || '').includes('Timeout') || String(error?.message || '').toLowerCase().includes('timeout')) throw providerError('PROVIDER_TIMEOUT');
        throw providerError('PROVIDER_TRANSPORT_ERROR');
      }
      if (response.status === 401 || response.status === 403) throw providerError('PROVIDER_AUTH_ERROR', response.status);
      if (response.status === 429) throw providerError('PROVIDER_QUOTA_EXCEEDED', response.status);
      if (!response.ok) throw providerError('PROVIDER_ERROR', response.status);
      let payload; try { payload = await response.json(); } catch { throw providerError('PROVIDER_INVALID_JSON'); }
      return { provider: this.name, modelVersion: model, elapsedMs: Date.now() - started, content: payload?.choices?.[0]?.message?.content };
    }
  };
}
