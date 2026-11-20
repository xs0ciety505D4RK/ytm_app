import { Readable } from 'node:stream';

const MAX_URL_LENGTH = 9000;
const MAX_REDIRECTS = 3;
const ALLOWED_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);

function isAllowedVideoUrl(value) {
  try {
    const url = new URL(value);
    const host = url.hostname.toLowerCase();
    return (
      url.protocol === 'https:' &&
      !url.username &&
      !url.password &&
      (!url.port || url.port === '443') &&
      (host === 'googlevideo.com' || host.endsWith('.googlevideo.com'))
    );
  } catch {
    return false;
  }
}

function readSourceUrl(encoded) {
  if (typeof encoded !== 'string' || encoded.length > MAX_URL_LENGTH) {
    return null;
  }
  try {
    const url = Buffer.from(encoded, 'base64url').toString('utf8');
    return isAllowedVideoUrl(url) ? url : null;
  } catch {
    return null;
  }
}

async function fetchVideo(url, init, redirects = 0) {
  const response = await fetch(url, { ...init, redirect: 'manual' });
  if (![301, 302, 303, 307, 308].includes(response.status)) return response;

  const location = response.headers.get('location');
  if (!location || redirects >= MAX_REDIRECTS) {
    return new Response('Too many or invalid redirects', { status: 502 });
  }
  const next = new URL(location, url).toString();
  if (!isAllowedVideoUrl(next)) {
    return new Response('Upstream redirect is not allowed', { status: 502 });
  }
  return fetchVideo(next, init, redirects + 1);
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Range, If-Range');
  res.setHeader('Access-Control-Expose-Headers', 'Accept-Ranges, Content-Length, Content-Range');
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('X-Content-Type-Options', 'nosniff');

  if (!ALLOWED_METHODS.has(req.method)) {
    res.setHeader('Allow', 'GET, HEAD, OPTIONS');
    return res.status(405).json({ error: 'method not allowed' });
  }
  if (req.method === 'OPTIONS') return res.status(204).end();

  const sourceUrl = readSourceUrl(req.query?.u);
  if (!sourceUrl) {
    return res.status(400).json({ error: 'invalid or unsupported stream URL' });
  }

  const range = req.headers.range;
  if (range && (typeof range !== 'string' || range.length > 128)) {
    return res.status(416).json({ error: 'invalid range header' });
  }

  try {
    const upstream = await fetchVideo(sourceUrl, {
      method: req.method,
      headers: {
        ...(range ? { Range: range } : {}),
        ...(req.headers['if-range'] ? { 'If-Range': req.headers['if-range'] } : {}),
        'Accept-Encoding': 'identity',
        Accept: '*/*',
        Referer: 'https://music.youtube.com/',
        'User-Agent':
          'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36',
      },
    });

    for (const name of [
      'accept-ranges',
      'content-length',
      'content-range',
      'content-type',
      'etag',
      'last-modified',
    ]) {
      const value = upstream.headers.get(name);
      if (value) res.setHeader(name, value);
    }

    res.status(upstream.status);
    if (req.method === 'HEAD' || !upstream.body) return res.end();
    Readable.fromWeb(upstream.body)
      .on('error', () => res.destroy())
      .pipe(res);
  } catch {
    if (!res.headersSent) {
      res.status(502).json({ error: 'audio upstream request failed' });
    } else {
      res.destroy();
    }
  }
}
