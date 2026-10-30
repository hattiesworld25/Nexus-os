# Nimbus Cloud + Atlas Lakehouse

Two independent, deployable Next.js prototypes backed by one Supabase project.

- **Nimbus Cloud**: account management; files/folders; uploads/downloads; expiring share links; photos; notes; contacts; calendar; reminders; search; recent items; storage usage; trash/restore/purge; AI assistant.
- **Atlas Lakehouse**: CSV/JSON/Parquet ingestion; private object storage; catalog/schema browser; DuckDB-Wasm SQL; query history; SQL/Markdown notebooks; chart builder; saved dashboards; working run-now pipelines that write result datasets; AI text-to-SQL.

This is original branding and code. It does not connect to, imitate the branding of, or access Apple iCloud, Databricks, or Google BigQuery.

## Accounts required

1. A free Supabase project: https://supabase.com/dashboard
2. Node.js 22+
3. Optional AI: an OpenAI API project and a model available to your account.
4. Optional deployment: Vercel account and a GitHub repository.

## 1. Create the backend

1. In Supabase, create one project.
2. Open **SQL Editor**, paste `supabase/migrations/001_nexus.sql`, and run it once.
3. In **Authentication > URL Configuration**, set the Site URL and add redirect URLs:
   - `http://localhost:3000/**`
   - `http://localhost:3001/**`
   - each exact deployed HTTPS domain followed by `/**`
4. In **Authentication > Providers**, keep Email enabled. For a private demo, you can turn off email confirmation; for any public demo, configure SMTP and keep confirmation on.
5. Copy **Project URL**, **Publishable/anon key**, and a **Secret key**. A legacy service-role key also works in `SUPABASE_SECRET_KEY`, but it must remain server-only.

## 2. Configure Nimbus Cloud

```bash
cd apps/cloud
cp .env.example .env.local
# Fill the variables documented in the file
npm install
npm test
npm run build
npm run dev
```

Open http://localhost:3000.

## 3. Configure Atlas Lakehouse

In a second terminal:

```bash
cd apps/lakehouse
cp .env.example .env.local
# Use the same Supabase project values
npm install
npm test
npm run build
npm run dev
```

Open http://localhost:3001.

## 4. Deploy

Push this folder to a private GitHub repository. In Vercel, create two projects from the same repo:

- Nimbus: Root Directory `apps/cloud`
- Atlas: Root Directory `apps/lakehouse`

Add each app's `.env.example` variables in **Project Settings > Environment Variables**. Use separate Supabase projects for staging and production. Redeploy after changing any `NEXT_PUBLIC_*` variable.

## Demo boundaries and production replacements

- Nimbus is a complete demo for user-owned content, not an Apple service. Production media workloads should add resumable uploads, malware scanning/quarantine, background thumbnail/video processing, legal retention, backups, and regional/compliance review. Supabase Storage can later be replaced by S3/R2 because paths and metadata are separated.
- Atlas executes analytics in the browser with DuckDB-Wasm. It deliberately caps each upload at 100 MiB and returns at most 500 preview rows. Replace the query engine with BigQuery, Databricks SQL, MotherDuck, or a server-side DuckDB service when data exceeds one-device memory, concurrency is required, scheduled jobs must run without an open browser, or enterprise governance is needed.
- Run-now pipelines are real: a read-only SQL result is converted to CSV, uploaded, cataloged, and immediately queryable. They are not background schedules.
- AI is optional and server-side. If keys are absent, every non-AI feature remains usable and the UI reports the missing configuration.

## Security checklist before public access

- Keep `SUPABASE_SECRET_KEY` and `OPENAI_API_KEY` server-only; never prefix them with `NEXT_PUBLIC_`.
- Use two test accounts and prove account B cannot read/update/delete account A's rows or storage objects.
- Keep RLS and storage policies enabled; never “fix” a permission error by disabling them.
- Set provider budgets/alerts, `AI_DAILY_LIMIT`, Supabase spend controls, upload limits, and retention.
- Add CAPTCHA/rate limits to public signup, configure SMTP, and scan untrusted files before downstream processing.
- Review allowed MIME types and privacy/terms for your use case. Do not put regulated or confidential data into a prototype without appropriate controls.

## Verification included

`npm test` runs deterministic security/utility tests in each app. The generated archive was checked for valid JSON, expected file references, and ZIP integrity. Live Supabase, OpenAI, email, browser, and Vercel tests still require your accounts and credentials.
