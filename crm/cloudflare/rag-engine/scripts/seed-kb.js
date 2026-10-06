// Chunks kb/*.md, embeds each chunk with Workers AI, and upserts into
// Vectorize (for retrieval) + KV (for the raw text, keyed by chunk id).
// Run with: CLOUDFLARE_API_TOKEN=... node scripts/seed-kb.js
const fs = require('fs');
const path = require('path');

const ACCOUNT_ID = 'd57383e4f0fc6159563863fab5681d31';
const KV_NAMESPACE_ID = 'b05bd1e9cfa7414fb7e057897783484a';
const VECTORIZE_INDEX = 'washnlaundry-kb';
const EMBEDDING_MODEL = '@cf/baai/bge-base-en-v1.5';

const token = process.env.CLOUDFLARE_API_TOKEN;
if (!token) {
  console.error('CLOUDFLARE_API_TOKEN is not set.');
  process.exit(1);
}

const API = `https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}`;
const headers = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };

function chunkMarkdown(source, text) {
  // Split on ## headings — each section becomes one chunk, small enough for
  // a single embedding and specific enough to cite usefully.
  const sections = text.split(/\n(?=## )/g).filter((s) => s.trim());
  return sections.map((section, i) => ({
    id: `${source}-${i}`,
    source,
    text: section.trim(),
  }));
}

async function embed(texts) {
  const res = await fetch(`${API}/ai/run/${EMBEDDING_MODEL}`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ text: texts }),
  });
  const data = await res.json();
  if (!data.success) {
    throw new Error(`Embedding failed: ${JSON.stringify(data.errors)}`);
  }
  return data.result.data;
}

async function upsertVectors(vectors) {
  const ndjson = vectors.map((v) => JSON.stringify(v)).join('\n');
  const res = await fetch(`${API}/vectorize/v2/indexes/${VECTORIZE_INDEX}/upsert`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/x-ndjson' },
    body: ndjson,
  });
  const data = await res.json();
  if (!data.success) {
    throw new Error(`Vectorize upsert failed: ${JSON.stringify(data.errors)}`);
  }
  return data.result;
}

async function putKV(key, value) {
  const res = await fetch(
    `${API}/storage/kv/namespaces/${KV_NAMESPACE_ID}/values/${encodeURIComponent(key)}`,
    { method: 'PUT', headers: { Authorization: `Bearer ${token}` }, body: value }
  );
  const data = await res.json();
  if (!data.success) {
    throw new Error(`KV put failed for ${key}: ${JSON.stringify(data.errors)}`);
  }
}

async function main() {
  const kbDir = path.join(__dirname, '..', 'kb');
  const files = fs.readdirSync(kbDir).filter((f) => f.endsWith('.md'));

  let allChunks = [];
  for (const file of files) {
    const source = path.basename(file, '.md');
    const text = fs.readFileSync(path.join(kbDir, file), 'utf8');
    allChunks = allChunks.concat(chunkMarkdown(source, text));
  }

  console.log(`Embedding ${allChunks.length} chunks from ${files.length} file(s)...`);
  const embeddings = await embed(allChunks.map((c) => c.text));

  const vectors = allChunks.map((chunk, i) => ({
    id: chunk.id,
    values: embeddings[i],
    metadata: { source: chunk.source, text: chunk.text.slice(0, 1000) },
  }));

  console.log('Upserting into Vectorize...');
  await upsertVectors(vectors);

  console.log('Writing raw text into KV...');
  for (const chunk of allChunks) {
    await putKV(chunk.id, chunk.text);
  }

  console.log(`Done. Indexed ${allChunks.length} chunks:`);
  for (const c of allChunks) console.log(`  - ${c.id}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
