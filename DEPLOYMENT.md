# Caplanner — Deployment Runbook (Render + Supabase Postgres)

Target: run the Rails 8.1 app on **Render**, with the database on **Supabase
Postgres**, carrying over the **exact current data** (users, subjects,
milestones, the 48 planned day-items, revision progress, the chat, and the 1834
`ruby_llm_models`).

Stack facts (already true in this repo):
- Rails `8.1.3`, Ruby `3.2.7`, `pg`, Puma + Thruster.
- Production uses **Solid Cache / Solid Queue / Solid Cable**, all on the single
  `DATABASE_URL` (see `config/database.yml` prod block: primary/cache/queue/cable).
- `config.force_ssl = true`, `config.assume_ssl = true`.
- Allowed hosts already include `*.onrender.com`, `RENDER_EXTERNAL_HOSTNAME`,
  and `APP_HOST` (`config/environments/production.rb`).
- `SOLID_QUEUE_IN_PUMA=true` → the worker runs inside the Puma process (one
  Render service is enough; no separate worker needed).

---

## 0. What "exact data" means here

Dump + restore these tables from `caplanner_development` → Supabase:

| Group | Tables |
|---|---|
| Domain | `users`, `subjects`, `revision_topics`, `milestones`, `milestone_subject_tasks`, `milestone_subject_task_items`, `daily_morning_mails`, `mock_test_results` |
| AI chat | `chats`, `messages`, and the whole `ruby_llm_*` set (esp. `ruby_llm_models` = 1834 rows) |
| Storage | `active_storage_*` (empty now, harmless) |
| Rails bookkeeping | `schema_migrations`, `ar_internal_metadata` |

Do **not** copy any `solid_queue_*` / `solid_cache_*` / `solid_cable_*` tables —
those are runtime infrastructure and get created fresh on Supabase in step 3.
(They don't exist in dev yet anyway.)

Current counts to verify after restore: users 1 · subjects 6 · revision_topics
30 · milestones 5 · milestone_subject_tasks 27 · milestone_subject_task_items 48
· chats 1 · messages 2 · ruby_llm_models 1834.

---

## 1. Create the Supabase project & get the two URLs

1. Create a Supabase project (choose a region near your Render region).
2. Project → **Settings → Database → Connection string**. You need BOTH:
   - **Direct** (port **5432**): `postgresql://postgres:<pw>@db.<ref>.supabase.co:5432/postgres`
     — used for migrations and the data restore.
   - **Transaction pooler** (port **6543**, host `aws-0-<region>.pooler.supabase.com`,
     user `postgres.<ref>`): `postgresql://postgres.<ref>:<pw>@aws-0-<region>.pooler.supabase.com:6543/postgres`
     — used by the running app.
3. Append `?sslmode=require` to both. Supabase requires TLS.

> Keep the password out of git. You'll paste these only into Render env vars and
> your local shell for the one-time restore.

---

## 2. Load the EXACT data into Supabase (pg_dump → restore)

Run locally, against the **direct** (5432) URL. `pg_dump`/`pg_restore` must match
the server's major version reasonably (Supabase is PG 15/16 — use a recent client).

```bash
# 2a. Dump the current dev DB, data + schema, EXCLUDING runtime infra tables.
pg_dump "postgresql://localhost/caplanner_development" \
  --no-owner --no-privileges \
  --exclude-table='solid_*' \
  --exclude-table-data='solid_*' \
  -Fc -f /tmp/caplanner.dump

# 2b. Restore into Supabase (DIRECT url, 5432). --clean so it's repeatable.
export SUPABASE_DIRECT_URL='postgresql://postgres:<pw>@db.<ref>.supabase.co:5432/postgres?sslmode=require'
pg_restore --no-owner --no-privileges --clean --if-exists \
  -d "$SUPABASE_DIRECT_URL" /tmp/caplanner.dump
```

If `pg_restore` complains about the `ar_internal_metadata` / `schema_migrations`
already existing, the `--clean --if-exists` flags handle it; a few NOTICE lines
are normal.

**Verify the restore** (direct URL):
```bash
psql "$SUPABASE_DIRECT_URL" -c "select
  (select count(*) from users) users,
  (select count(*) from milestone_subject_task_items) items,
  (select count(*) from ruby_llm_models) models,
  (select count(*) from messages) messages;"
# expect: users 1 | items 48 | models 1834 | messages 2
```

---

## 3. Create the Solid (queue/cache/cable) tables on Supabase

Production needs the three Solid schemas. They live under separate migration
paths (`db/queue_migrate`, `db/cache_migrate`, `db/cable_migrate`). These dirs
are currently EMPTY in this repo, so generate the schemas first, commit them,
then they load on deploy.

```bash
# Generate the Solid infra migrations (once, locally; commit the results).
bin/rails solid_queue:install   # creates db/queue_migrate + config/queue.yml (exists)
bin/rails solid_cache:install   # creates db/cache_migrate
bin/rails solid_cable:install   # creates db/cable_migrate
git add db/queue_migrate db/cache_migrate db/cable_migrate
git commit -m "Add Solid Queue/Cache/Cable migrations for production"
```

> If a generator reports the files already exist, good — skip it. The important
> thing is that `db/{queue,cache,cable}_migrate` contain migrations before deploy.

They get applied in step 5 by `db:prepare` against each database (all three
point at the same Supabase DB via `DATABASE_URL`).

---

## 4. Create the Render Web Service

1. Push this repo to GitHub.
2. Render → **New → Web Service** → connect the repo.
3. Runtime: **Docker** (this repo has a `Dockerfile`). Render auto-detects it.
4. Region: same as Supabase.
5. **Environment variables** (Render → Environment):

   | Key | Value |
   |---|---|
   | `DATABASE_URL` | the **transaction pooler** URL (6543) + `?sslmode=require` |
   | `RAILS_MASTER_KEY` | contents of `config/master.key` (NOT committed) |
   | `RAILS_ENV` | `production` |
   | `OPENAI_API_KEY` | your OpenAI key (EURA + nightly re-plan + briefs) |
   | `OPENAI_MODEL` | `gpt-4o-mini` (optional; this is the default) |
   | `SMTP_USER` | Gmail/app SMTP user (for morning + nightly emails) |
   | `SMTP_PASSWORD` | SMTP app password |
   | `SMTP_ADDRESS` | `smtp.gmail.com` (optional; default) |
   | `SMTP_PORT` | `587` (optional; default) |
   | `PLANNER_FROM` | the "from" address for emails |
   | `APP_HOST` | your Render URL host, e.g. `caplanner.onrender.com` (for email links) |
   | `SOLID_QUEUE_IN_PUMA` | `true` |
   | `WEB_CONCURRENCY` | `2` (tune to the Render plan) |

   Notes:
   - Use the **pooler** URL here. Because pgBouncer runs in transaction mode,
     prepared statements must be off — see step 6 (one-line config change).
   - The nightly re-plan emails a FIXED address (`agarwaldivy2508@gmail.com`,
     in `PlannerMailer::NIGHT_REPLAN_TO`); morning brief goes to the app user.

---

## 5. Migrations run automatically on boot (no extra command needed)

The `Dockerfile` entrypoint (`bin/docker-entrypoint`) ALREADY runs
`./bin/rails db:prepare` before starting the server:

```bash
if [ "${@: -2:1}" == "./bin/rails" ] && [ "${@: -1:1}" == "server" ]; then
  ./bin/rails db:prepare
fi
```

So on each deploy, `db:prepare` runs against Supabase (all four DBs share
`DATABASE_URL`), creating the Solid queue/cache/cable tables and applying any
pending migrations — **without dropping data**. Because the domain data was
already restored in step 2, this just ensures the infra tables exist.

- **No Render Pre-Deploy command is required.** Leave it blank.
- Caveat: `db:prepare` runs inside the web process at boot. The pooler URL works
  for this. If you ever hit pooler issues during migration, temporarily point
  `DATABASE_URL` at the DIRECT (5432) URL for one deploy, then switch back.

---

## 6. One required code change for the Supabase pooler

The transaction pooler (pgBouncer) does not support prepared statements. Add this
to the production primary DB config so Rails disables them:

`config/database.yml` → `production: → primary:` (and the cache/queue/cable
blocks, since they share the URL) add:

```yaml
    prepared_statements: false
```

(If you prefer, append `&prepared_statements=false` is NOT valid in a URL for
Rails — set it in database.yml as above, or via `PGOPTIONS`. database.yml is the
reliable place.)

Commit this before deploying.

---

## 7. First deploy & smoke test

1. Trigger the Render deploy (push to the connected branch).
2. Watch logs (`Logs` tab). The Pre-Deploy runs `db:prepare`; the web process
   boots Puma with Solid Queue embedded.
3. Smoke checks once live (`https://<app>.onrender.com`):
   - `/up` → 200 (Rails health check).
   - `/` dashboard renders: today's blocks (IDT #18, DT #54, AU #45, FR Rev 1
     Inventories), the EURA chat with greeting + schedule, Roadmap + Subjects.
   - Click a block Done → progress ring updates AND EURA posts a cheer in chat
     (confirms Solid Cable + Solid Queue work on Supabase).
   - Type to EURA → a reply streams in (confirms the AI key + cable).
4. The scheduled jobs (morning brief 7am, nightly re-plan 10pm) are in
   `config/recurring.yml` and run via Solid Queue inside Puma — no extra service.

---

## 8. Rollback / re-run notes

- Re-running the data load: step 2b with `--clean --if-exists` is idempotent —
  it wipes and reloads the domain tables. (It will reset any progress the live
  user made, so only re-run intentionally.)
- Schema-only change later: just push; the Pre-Deploy `db:prepare` migrates.
- To inspect prod data: `psql "$SUPABASE_DIRECT_URL"` (use the DIRECT 5432 URL
  for admin/SQL, not the pooler).

---

## Checklist

- [ ] Supabase project created; direct (5432) + pooler (6543) URLs saved.
- [ ] Solid queue/cache/cable migrations generated & committed (step 3).
- [ ] `prepared_statements: false` added to prod database.yml (step 6).
- [ ] Data dumped & restored to Supabase; counts verified (step 2).
- [ ] Render web service created (Docker), env vars set (step 4).
- [ ] (No Pre-Deploy needed — entrypoint runs `db:prepare` on boot, step 5.)
- [ ] Deployed; `/up` 200; dashboard + EURA + block-cheer verified (step 7).
