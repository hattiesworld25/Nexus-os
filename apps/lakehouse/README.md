# Atlas Lakehouse

Run the root `README.md` setup first. Required variables are in `.env.example`.

```bash
npm install
npm test
npm run build
npm run dev
```

Verification: upload a small CSV; click Load; query its generated dataset name; inspect history; save/run a notebook cell; build/save/reopen a chart; create a pipeline and confirm it writes a new catalog dataset; sign in as a second user and verify isolation. Text-to-SQL additionally requires `OPENAI_API_KEY` and `OPENAI_MODEL`.

DuckDB-Wasm is intentionally browser-local and memory-limited. Do not use this demo for secrets or large production workloads.
