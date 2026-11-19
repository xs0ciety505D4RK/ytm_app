// Proxy tipis ke API YouTube Music + cache edge Vercel.
// App mengirim: GET /api/yt?e=browse&b=<base64url(JSON body)>
const BASE = 'https://music.youtube.com/youtubei/v1';
const KEY = 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';
const TTL = { browse: 900, search: 600, next: 300 };

export default async function handler(req, res) {
  const e = String(req.query.e || '');
  const b = String(req.query.b || '');
  if (!(e in TTL) || !b || b.length > 4000) {
    return res.status(400).json({ error: 'bad request' });
  }
  let body;
  try {
    body = Buffer.from(b, 'base64url').toString('utf8');
    JSON.parse(body);
  } catch {
    return res.status(400).json({ error: 'bad body' });
  }
  try {
    const r = await fetch(`${BASE}/${e}?prettyPrint=false&key=${KEY}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Origin: 'https://music.youtube.com',
        Referer: 'https://music.youtube.com/',
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
      },
      body,
    });
    const text = await r.text();
    res.setHeader('Content-Type', 'application/json');
    if (r.ok) {
      res.setHeader('Cache-Control', `s-maxage=${TTL[e]}, stale-while-revalidate=3600`);
    }
    res.status(r.status).send(text);
  } catch (err) {
    res.status(502).json({ error: String(err.message || err) });
  }
}
