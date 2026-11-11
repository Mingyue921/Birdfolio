export function createMailProvider(env, options = {}) {
  const fetchImpl = options.fetchImpl || fetch;
  const endpoint = String(env.MAIL_PROVIDER_URL || '').trim();
  const token = String(env.MAIL_PROVIDER_TOKEN || '').trim();
  return {
    configured: endpoint.length > 0,
    async sendVerificationCode({ email, code, expiresIn }) {
      if (!endpoint) throw new Error('EMAIL_NOT_CONFIGURED');
      const headers = { 'content-type': 'application/json' };
      if (token) headers.authorization = `Bearer ${token}`;
      const response = await fetchImpl(endpoint, { method: 'POST', headers, body: JSON.stringify({ to: email, code, expiresIn, template: 'birdfolio-login-code' }), signal: AbortSignal.timeout(Number(env.MAIL_PROVIDER_TIMEOUT_MS || 5000)) });
      if (!response.ok) throw new Error('PROVIDER_UNAVAILABLE');
    }
  };
}
