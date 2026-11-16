# CA Planner

A personal CA Final preparation portal. It guides your syllabus, tracks daily
productivity, and emails you a **morning brief** (today's blocks) and an
**evening review** (how today went).

Built for a single user — no login. Your email lives in **Settings**.

## What it does

- **Today dashboard** — the day's four study blocks (generated from the weekly
  rotation in your timetable), tickable live, plus streak and 7-day average.
- **Subjects** — lecture progress per paper (FR, AFM, Audit, DT, GST, IBS).
- **Productivity logs** — nightly check-ins (walk / water / sleep / mood /
  notes); study-block completion is counted automatically.
- **Emails** — morning brief + evening review, previewable from the dashboard.

## Running locally

```bash
bin/rails db:setup      # create + migrate + seed subjects (first time only)
bin/rails server        # http://localhost:3000
```

### Previewing emails in development

Email is set to **file delivery** in development — every send is written to
`tmp/mails/` as an openable `.html` file. Click the buttons on the dashboard
("Email morning brief" / "Email evening review") or run:

```bash
bin/rails planner:morning
bin/rails planner:evening
```

## Sending real email

Set these environment variables (Gmail example — create a 16-char **App
Password**, not your login password):

```bash
export SMTP_ADDRESS=smtp.gmail.com
export SMTP_PORT=587
export SMTP_USER=bhaskar19191@gmail.com
export SMTP_PASSWORD=your-16-char-app-password
export PLANNER_FROM=bhaskar19191@gmail.com
```

Real SMTP is wired for `production`. Run in production mode (or set
`config.action_mailer.delivery_method = :smtp` in development) to actually send.

## Scheduling the daily emails (cron)

The rake tasks are self-contained, so cron is the simplest reliable scheduler.
`crontab -e` and add (adjust the path and your preferred times):

```cron
# 7:00 AM — morning brief
0 7 * * *  cd /home/startbit/Desktop/ruby/caplanner && RAILS_ENV=production bin/rails planner:morning >> log/cron.log 2>&1
# 10:00 PM — evening review
0 22 * * * cd /home/startbit/Desktop/ruby/caplanner && RAILS_ENV=production bin/rails planner:evening >> log/cron.log 2>&1
```

The hours in **Settings** are informational for now; cron controls actual
send times. Keep them in sync.

## Goal-driven planning toward the exam

The planner steers toward your **CA Final attempt date** (default 2 May 2027,
editable in Settings). Everything left is tracked as `SyllabusGoal` rows — one
per subject × task type: **lectures, revision 1, revision 2, mocks**. The
**Roadmap** page shows what's left, days remaining, the pace needed, and whether
you're on track, and lets you edit any count.

Phases (your chosen order): **lectures → first revision → (mocks + second
revision together)** near the end. `RoadmapService` decides the current phase
from what's still pending and how close the exam is.

### The nightly loop

Each night on the dashboard: tick the blocks you finished, then type a free-text
note of what's still left or skipped ("did GST ch1–3, skipped Audit — push it
tomorrow"). Saving runs `NextDayPlanner` for the next day:

- With `GROQ_API_KEY` set, Groq reads your note + the roadmap and builds the
  best schedule, acting on what you said.
- Without a key, a **goal-aware rule engine** plans deterministically from the
  roadmap math (it honours the phase and the furthest-behind subjects, but can't
  read your free-text — that's the AI's job).

Ticking a lecture/revision/mock block automatically advances the matching
`SyllabusGoal`, so the roadmap always reflects real progress.

Enable AI by setting:

```bash
export GROQ_API_KEY=gsk_your_key_here
# optional overrides:
export GROQ_MODEL=llama-3.3-70b-versatile          # default
export GROQ_API_BASE=https://api.groq.com/openai/v1 # default
```

Groq is reached through RubyLLM's OpenAI-compatible provider
(`config/initializers/ruby_llm.rb`).

## Pages

- **Today** — dashboard with the day's blocks (planned + completed time,
  pending/overdue flags), productivity ring, week strip, exam countdown, and the
  nightly update box.
- **Roadmap** — progress toward the exam across lectures / rev 1 / rev 2 / mocks,
  days left, pace needed, on-track status, and an editable per-subject matrix.
- **Calendar** — month grid; each day coloured by completion %, AI-planned days
  marked.
- **Analytics** — Chartkick charts: completion trend, blocks/day, per-subject
  progress and remaining, block-of-day completion, health check-ins.

## How the day plan is built

`DayPlanGenerator` (`app/services/day_plan_generator.rb`) holds the weekly
rotation and block clock-times from the master timetable. `DayPlan.for(date)`
returns an existing plan or generates one on demand. To change a day (festival
buffer, MCS, etc.), edit its tasks or use **Regenerate from rotation** on the
day page.

## Tests

```bash
bin/rails test
```
