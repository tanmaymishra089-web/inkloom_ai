# Start here — run the complete ZIP on a fresh computer

Extract the ZIP and open its single **inkloom-ai/** folder. Choose **A: Docker**
for the simplest whole-app setup, or **B: Direct startup** if Docker is unavailable.
Do not run both routes on port 8017 at the same time. All commands below start
inside the extracted `inkloom-ai` folder. Real secrets and installed dependencies
are intentionally absent; `.env.example` contains local placeholder values only.

## Prerequisites

- **Docker route:** Docker Desktop on Windows/macOS, or Docker Engine + Compose v2
  on Linux. Start Docker first. Allocate several GB of free disk for image layers.
  `docker --version` and `docker compose version` must succeed. Windows Docker
  Desktop must use Linux containers (usually with WSL 2).
- **Direct route:** Python **3.11 or 3.12** (tested here with 3.12), Node.js **24 LTS**
  and npm, PostgreSQL **16**, and **pgvector installed on the PostgreSQL server**.
  Add `python`/`py`, `node`, `npm`, and `psql` to PATH. On Windows, the PostgreSQL
  installer normally places psql in `C:\Program Files\PostgreSQL\16\bin`.
- The Python `pgvector` dependency does **not** install the PostgreSQL extension.
  Install a compatible server build before the direct DB setup below. Follow the
  upstream [pgvector v0.8.0 installation instructions](https://github.com/pgvector/pgvector/tree/v0.8.0#installation).
  Windows source installation requires Visual Studio C++ build tools, `PGROOT`
  pointing to PostgreSQL 16 and an administrator developer command prompt for
  `nmake /F Makefile.win` and `nmake /F Makefile.win install`. On macOS/Linux,
  build against the PostgreSQL 16 `pg_config` using `make` and `make install`
  (administrative permission may be needed). A managed PostgreSQL server with
  pgvector enabled is also supported and does not require Docker locally.
- Internet is needed to download dependencies/images. An OpenAI key is **optional**
  for rule checks; semantic inference remains incomplete without it.

## A. Docker — whole app, database, migrations and seed

This route uses **compose.release.yml**, not the older backend-only Compose file.
It builds the React frontend into the FastAPI image and serves UI and API together.
Migration and idempotent seed commands run automatically in `start_release.py`.

**Windows PowerShell:**

```powershell
Set-Location "C:\path\to\inkloom-ai"
Copy-Item .env.example .env
notepad .env
docker compose -f compose.release.yml config --quiet
docker compose -f compose.release.yml up --build -d
docker compose -f compose.release.yml logs -f app
```

**macOS/Linux:**

```sh
cd /path/to/inkloom-ai
cp .env.example .env
# Edit .env with your editor; for a local fictional demo its defaults work.
docker compose -f compose.release.yml config --quiet
docker compose -f compose.release.yml up --build -d
docker compose -f compose.release.yml logs -f app
```

Open **http://localhost:8017** after startup finishes. `Ctrl+C` exits log-following
without stopping the background app. Use the hostname **localhost**, not an IP
alias, to match the configured browser origin. The local Compose file explicitly
enables demo cookies for HTTP; do not reuse those cookie settings for public HTTPS.

Stop without deleting data:

```sh
docker compose -f compose.release.yml down
```

Do **not** add `-v` unless you intentionally want to delete the local demo database.
Changing POSTGRES_PASSWORD after the volume has been initialized does not change
the existing database role password. For this local-only example, the placeholder
`local-development-only` matches the documented connection URL; replace it before
any public use and keep the password and URL consistent.

**Verification limit:** Compose configuration was validated, but the full Docker
image was not successfully built in the cloud executor: image unpacking failed
with **no space left on device**. This ZIP does not claim a verified container
startup. Free/allocate disk on your machine before building; do not delete unrelated
volumes or data. Route B is the independently exercised application startup path.

## B. Direct startup — no Docker required

**Platform limit:** the text-based judge workflow can be started with the native
PowerShell commands below, but native Windows startup is not exercised in this
Linux executor. PDF/DOCX parser isolation imports Python's Unix `resource` module;
that upload path and its tests do not work natively on Windows. Use Linux under
WSL2 (the Linux commands below, even without Docker) or Docker for the full parser
and backend suite. macOS parser resource behavior is also unverified here. This
package preserves the existing security limits rather than disabling them.

### B1. Prepare a PostgreSQL database

Use a fresh local development database. Start your PostgreSQL service and ensure
pgvector's extension files are installed for that server version. These commands
create only a new `inkloom` database and role; they fail harmlessly if those names
already exist. In that case reuse your known development DB or choose another
name and update DATABASE_URL. Never drop an existing database to follow this guide.

**Windows PowerShell** (psql prompts for the installation administrator password):

```powershell
$DbAdmin = "postgres"
psql -h localhost -U $DbAdmin -d postgres -c "CREATE ROLE inkloom WITH LOGIN PASSWORD 'local-development-only';"
psql -h localhost -U $DbAdmin -d postgres -c "CREATE DATABASE inkloom OWNER inkloom;"
psql -h localhost -U $DbAdmin -d inkloom -c "CREATE EXTENSION IF NOT EXISTS vector;"
psql -h localhost -U $DbAdmin -d inkloom -c "SELECT extversion FROM pg_extension WHERE extname='vector';"
```

**macOS/Linux** (set the actual PostgreSQL administrator for your installation):

```sh
PG_ADMIN=postgres
# Homebrew PostgreSQL commonly uses your macOS login: PG_ADMIN="$(whoami)"
psql -h localhost -U "$PG_ADMIN" -d postgres -c "CREATE ROLE inkloom WITH LOGIN PASSWORD 'local-development-only';"
psql -h localhost -U "$PG_ADMIN" -d postgres -c "CREATE DATABASE inkloom OWNER inkloom;"
psql -h localhost -U "$PG_ADMIN" -d inkloom -c "CREATE EXTENSION IF NOT EXISTS vector;"
psql -h localhost -U "$PG_ADMIN" -d inkloom -c "SELECT extversion FROM pg_extension WHERE extname='vector';"
```

Linux packages may use peer authentication for the `postgres` administrator. In
that case run each SQL statement using `sudo -u postgres psql` instead of the TCP
administrator command, or configure a local administrator password. The app's
own connection is TCP with the `inkloom` role and password, not the administrator.
If `vector` is unavailable, install the server extension first; migration cannot
substitute SQLite or the Python pgvector package for it.

### B2. Install, configure, migrate, seed and start

The recommended direct route builds the frontend and serves it from FastAPI on
one origin. No frontend development server is required once `npm run build` passes.

**Windows PowerShell:**

```powershell
Set-Location "C:\path\to\inkloom-ai"
py -3.12 -m venv .venv
# If using Python 3.11, replace -3.12 above with -3.11.
& .\.venv\Scripts\python.exe -m pip install -r backend\requirements.txt
Copy-Item .env.example .env
notepad .env
# Set DATABASE_URL if your server/role/password differs from the local defaults.
# Keep OPENAI_API_KEY empty for the rule-only demo.
Push-Location frontend
npm ci
npm run typecheck
npm run build
Pop-Location
$env:DEMO_ENABLED = "true"
$env:DEMO_COOKIE_SECURE = "false"
$env:CORS_ORIGINS = '["http://localhost:8017"]'
$env:FRONTEND_DIST = (Resolve-Path .\frontend\dist).Path
$env:EXPOSE_API_DOCS = "false"
Set-Location backend
& ..\.venv\Scripts\python.exe -m alembic upgrade head
& ..\.venv\Scripts\python.exe -m app.services.seed
& ..\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8017
```

**macOS/Linux:**

```sh
cd /path/to/inkloom-ai
python3.12 -m venv .venv
# Use python3.11 instead if that is the installed supported interpreter.
.venv/bin/python -m pip install -r backend/requirements.txt
cp .env.example .env
# Edit .env if the DB differs; leave OPENAI_API_KEY empty for rule-only testing.
(cd frontend && npm ci && npm run typecheck && npm run build)
export DEMO_ENABLED=true
export DEMO_COOKIE_SECURE=false
export CORS_ORIGINS='["http://localhost:8017"]'
export FRONTEND_DIST="$(pwd)/frontend/dist"
export EXPOSE_API_DOCS=false
cd backend
../.venv/bin/python -m alembic upgrade head
../.venv/bin/python -m app.services.seed
../.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8017
```

Open **http://localhost:8017**. Keep the server terminal open. `Ctrl+C` stops it;
PostgreSQL retains saved records. On each restart, repeat the environment-variable
assignments and uvicorn command (or put the equivalent values in your private
root `.env`, using an absolute FRONTEND_DIST path). Seeding is idempotent and can
be repeated. Do not run production with local HTTP cookie settings.

### B3. Optional Vite frontend development server

For hot reload, omit FRONTEND_DIST from the backend environment and enable docs
if wanted. Set CORS_ORIGINS to `["http://localhost:5173"]` and run uvicorn on
**8015**. In a second terminal, run `npm run dev` from `frontend/`. Its default
proxy sends `/api` to `http://127.0.0.1:8015`; open **http://localhost:5173**.
For a different backend port, set API_PROXY_TARGET in `frontend/.env` copied
from `frontend/.env.example`. Keep VITE_API_ORIGIN empty for same-origin requests.

PowerShell clears inherited release settings with:
`Remove-Item Env:FRONTEND_DIST -ErrorAction SilentlyContinue`.
macOS/Linux: `unset FRONTEND_DIST`. Also remove any FRONTEND_DIST entry from the
private `.env` if you previously added one. The full B2 release route is simpler
for judging and does not require this optional two-server setup.

## C. Try the demo without an LLM key

Try Live Demo → inspect Punjab Coffee House's approved **₹129** price and rules →
Create content → Load Example → Save → Run AI Review → inspect the actual price
fact and unverified ranking guideline → accept price correction → recheck →
request approval → Switch to Reviewer (Demo) → explicitly acknowledge incomplete
checks and write a reason → Approve or Request Changes → History.

Missing LLM credentials intentionally produce **partial / incomplete** review.
Deterministic price/rule checks still run. A lexical ranking warning is unverified,
not a claim of falsehood or successful semantic inference. Creator and Reviewer
are simulated roles within your isolated session, not production user accounts.

To enable real inference separately, edit only the **root private `.env`**:

```dotenv
LLM_PROVIDER=openai
LLM_MODEL=gpt-4.1-mini
OPENAI_API_KEY=replace-with-your-own-server-side-key
```

Use your provider's valid key, billing and model access. Restart the direct backend
or run `docker compose -f compose.release.yml up -d --force-recreate app` so it
receives updated environment values. Never put the key in a VITE_ variable,
frontend source, Git or chat. Review cost/time/token limits are in `.env.example`.
Real inference is not verified merely by adding a key; inspect a completed review
and its persisted output. Historical partial reviews stay partial until a new
review is explicitly run.

## D. Tests and smoke checks

Use a **separate disposable database** for pytest; migration tests must never run
against your working/demo database. Create it and enable vector as in B1, with
name `inkloom_test`, then migrate before running the suite.

PowerShell, from the project root:

```powershell
$env:DATABASE_URL = "postgresql+psycopg://inkloom:local-development-only@localhost:5432/inkloom_test"
Push-Location backend
& ..\.venv\Scripts\python.exe -m alembic upgrade head
& ..\.venv\Scripts\python.exe -m pytest -q -rs
Pop-Location
Remove-Item Env:DATABASE_URL
Push-Location frontend
npm test
npm run typecheck
npm run build
npx playwright install chromium
$env:FRONTEND_URL = "http://localhost:8017"
npm run test:e2e
Pop-Location
& .\.venv\Scripts\python.exe scripts\phase4_smoke.py --url http://localhost:8017 --expect-docs-disabled
```

macOS/Linux, from the project root:

```sh
(cd backend && \
 export DATABASE_URL='postgresql+psycopg://inkloom:local-development-only@localhost:5432/inkloom_test' && \
 ../.venv/bin/python -m alembic upgrade head && ../.venv/bin/python -m pytest -q -rs)
(cd frontend && npm test && npm run typecheck && npm run build)
(cd frontend && npx playwright install chromium)
(cd frontend && FRONTEND_URL=http://localhost:8017 npm run test:e2e)
.venv/bin/python scripts/phase4_smoke.py --url http://localhost:8017 --expect-docs-disabled
```

Browser/smoke checks need a running, seeded **disposable demo server** in a
separate terminal and create fictional records. Browser acceptance tests expect
missing LLM credentials; do not run them with paid provider credentials enabled.
Playwright uses its installed Chromium by default. Alternatively set CHROMIUM_PATH
to a real installed Chrome/Chromium executable. BROWSER_OUTPUT_DIR selects an
artifact directory; otherwise tests use local `frontend/test-results/`. Linux
may need `npx playwright install --with-deps chromium` with system-package privileges.
Live-provider tests are opt-in and may incur charges; the ordinary suite skips them.

## E. Publish extracted source later (empty GitHub repository)

This ZIP intentionally excludes `.git`; the original repository and baseline
history remain untouched in the original workspace. The following commands make
**new Git history for the extracted copy only**. To preserve the original history
on GitHub, publish from the original repository instead; never force-push.

Install Git and GitHub CLI, authenticate with your own valid account, and use the
actual empty repository URL. No push was attempted while preparing this package.

```sh
git init
git branch -M main
git status --short --untracked-files=all
# Review files first. .env, dependencies, DB files and build output are ignored.
git add .
git diff --cached --check
git diff --cached --stat
git diff --cached
git commit -m "Add Inkloom AI Phase 6 source"
gh auth login --hostname github.com --git-protocol https --web
git remote add origin https://github.com/tanmaymishra089-web/inkloom_ai.git
git push -u origin main
```

Configure your own `git config user.name` and `git config user.email` if Git asks.
If GH_TOKEN is set to an invalid value, clear/fix that override before login.
If the remote is not empty, stop and inspect its history; do not force-push or
replace its files blindly. Check the real GitHub page after a successful push.
See `docs/phase6-release.md` for public HTTPS deployment and its unverified blockers.

---

# Previous release and phase verification notes

# Inkloom AI — Round 2 release

**Public app: not deployed. Source repository: not published.**
Publishing is blocked by missing runtime/database hosting access and GitHub HTTP
401 authentication. See [release verification](docs/phase6-release.md) for actual
results; no public URL or successful model inference is claimed.

## Judge journey (no terminal after opening the app)

1. Open the app and choose **Try Live Demo**. Inspect the read-only sample Brand
   Hub: Premium Coffee **₹129**, warm/professional/trustworthy tone, and guidance
   against unsupported superlatives.
2. Choose Create content → Load Example → Save content → Run AI Review. The exact
   example is **Our Premium Coffee is the best in Punjab, now only ₹99!**
3. Inspect the price contradiction and resolve its actual approved fact. Ranking
   language is marked **unverified**, not false. Missing provider credentials
   visibly leave semantic review incomplete.
4. Accept the price correction as a new version and run the review again. The
   corrected price no longer contradicts the fact; the ranking remains unverified.
   Inspect/dismiss findings only with a written reason where appropriate.
5. Request approval → Switch to Reviewer (Demo) → write a reason and explicitly
   acknowledge missing checks/unresolved serious findings, then Approve or Request
   Changes. Inspect saved decisions and immutable versions in History.
6. Switch back to Creator and submit entirely different text, e.g. **☕ Premium
   Coffee for ₹88 today.** Checks use stored rules/facts, not canned responses.

Creator/Reviewer are simulated roles within one guest session. An AI review is
never a human approval. Editing approved content creates an unapproved version.

## Architecture and release setup

React/Vite/TypeScript/Tailwind + TanStack Query → same-origin FastAPI `/api` →
SQLAlchemy/PostgreSQL 16 with pgvector installed. LangGraph invokes deterministic
checks and a configurable hosted LLM; retrieval currently uses scoped keywords.
Version hashes, reviews, citations, approvals and audit events persist in Postgres.
Extracted PDF/DOCX text and metadata also persist there; original uploads are not
kept on ephemeral disk. OCR and vector search are not implemented.

Local development: see [frontend quickstart](frontend/README.md). For the unified
release runtime, build the frontend then run FastAPI with FRONTEND_DIST pointing
to its absolute `dist` path:

```sh
cd frontend
npm ci
npm run typecheck
npm test
npm run build
cd ../backend
# Set DATABASE_URL to your dedicated migrated PostgreSQL database first.
../.venv/bin/python -m alembic upgrade head
../.venv/bin/python -m app.services.seed
FRONTEND_DIST="$(cd ../frontend/dist && pwd)" EXPOSE_API_DOCS=false \
DEMO_ENABLED=true DEMO_COOKIE_SECURE=false CORS_ORIGINS='["http://localhost:8017"]' \
../.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8017
```

Open http://localhost:8017. Frontend requests remain relative `/api` URLs; no
localhost API address is embedded in the production bundle. For hosted HTTPS set
DEMO_COOKIE_SECURE=true and CORS_ORIGINS to a JSON array of the exact public HTTPS
origin. Keep VITE_API_ORIGIN empty. Database credentials and OPENAI_API_KEY remain
server-only. Never place them in VITE_ variables or commit `.env`.

The root Dockerfile builds this unified runtime and `render.yaml` describes a
paid Docker service plus persistent PostgreSQL 16. `scripts/start_release.py`
normalizes the provider database URL, runs existing Alembic migrations and the
idempotent seed, then starts the app on PORT. The local Docker build could not
finish because the executor ran out of disk space; image deployment is unverified.
See [deployment and publishing steps](docs/phase6-release.md) before applying the
blueprint, including account setup, costs, pgvector support and HTTPS checks.

## Release verification commands

Run backend tests only with DATABASE_URL pointing to a disposable test database.

```sh
cd backend
../.venv/bin/python -m pytest -q -rs
../.venv/bin/python -m pip check
cd ../frontend
npm test
npm run typecheck
npm run build
npm audit
FRONTEND_URL=http://localhost:8017 npm run test:e2e
AUDIT_MOBILE=1 FRONTEND_URL=http://localhost:8017 npm run test:e2e
cd ..
.venv/bin/python scripts/phase4_smoke.py --url http://localhost:8017 --expect-docs-disabled
git diff --check
```

Live LLM inference is opt-in and remains UNVERIFIED until an actual configured
provider succeeds and its persisted output is inspected. Lexical ranking checks
only identify language requiring review; they do not prove a ranking true/false.

---

## Earlier phase notes (historical context)

# Inkloom AI — Phase 3 backend

Working backend with deterministic checks, PDF/DOCX ingestion, keyword retrieval,
and a LangGraph review workflow with an optional OpenAI semantic provider.
Live LLM inference has not been verified in this environment because no credential
is configured. No frontend, public deployment or remote repository is included. Requires Python 3.11+ and Docker Compose v2.

## Docker setup

From this repository root:

```sh
cp .env.example .env
# Replace the local password if desired, consistently in DATABASE_URL.
docker compose up --build -d
docker compose exec backend python -m app.services.seed
curl -f http://localhost:8000/api/health
curl -f http://localhost:8000/api/ready
```

API docs: http://localhost:8000/docs. Compose runs `alembic upgrade head` before
starting the API and waits for PostgreSQL health. Data persists in postgres_data.
The API and DB ports bind to 127.0.0.1 only. `.env` is ignored by Git.

For local demo exploration, set `DEMO_ENABLED=true` in `.env`, then:

```sh
docker compose up -d --force-recreate backend
curl -X POST http://localhost:8000/api/demo/sessions
```

Copy the returned token into Swagger's request Authorization header as
`Bearer TOKEN` (each protected operation exposes this header field). First call
POST /api/demo/example to obtain your isolated Punjab Coffee House example.
Then list kits and retrieve knowledge using the returned workspace and kit IDs.
Do not publish this development setup. See docs/architecture.md for Phase 4 gaps.

## Host development

```sh
cp .env.example .env  # only if .env does not already exist
python3 -m venv .venv
.venv/bin/pip install -r backend/requirements.txt
docker compose up -d db
cd backend
../.venv/bin/alembic upgrade head
../.venv/bin/python -m app.services.seed
../.venv/bin/uvicorn app.main:app --reload
```

Host commands load the repository root `.env`, then an optional `backend/.env`
override. Exported environment variables take precedence over both files.
Never commit either file.
CORS_ORIGINS is an explicit JSON array of frontend origins, not a wildcard.

## Tests and migrations

Tests use a real migrated PostgreSQL database and create test sessions/workspaces.
Use a separate test database, not private production data:

```sh
docker compose exec db createdb -U inkloom inkloom_test
cd backend
export DATABASE_URL=postgresql+psycopg://inkloom:local-development-only@localhost:5432/inkloom_test
../.venv/bin/alembic upgrade head
../.venv/bin/python -m pytest -q
../.venv/bin/alembic check
# Destructive migration roundtrip: only on the test database!
../.venv/bin/alembic downgrade base
../.venv/bin/alembic upgrade head
```

The suite checks process health, DB readiness/failure, session isolation,
validation, workspace creation/read/list, facts/rules, draft cloning, immutable
approval at API and SQL levels, seed idempotency/API retrieval, and vector size.
No tests substitute SQLite for PostgreSQL. Exact dependencies are pinned.

## Cleanup

```sh
# Stop containers; retain data:
docker compose down
# Destructive: remove all local database data:
docker compose down -v
# Optional: remove the project-local virtual environment:
rm -rf .venv
```

See docs/phase2-handoff.md for the API and data model contract.

## Custom HTTPS proxy CA (optional)

If a managed environment intercepts HTTPS, supply its trusted CA bundle as a
BuildKit secret. It is used only during pip installation and is not copied into
the image. Ordinary machines need no override:

```sh
INKLOOM_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt docker compose -f docker-compose.yml -f docker-compose.cloud.yml up --build -d
```

## Live API smoke test

To test the complete Phase 1 API against a running local development server:

```sh
# Terminal 1, from backend/ (development only):
DEMO_ENABLED=true ../.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8002
# Terminal 2, from the repository root:
.venv/bin/python scripts/smoke.py
```

Run the seed command first. The smoke script creates an isolated session and
sample workspaces; it checks seed facts, draft changes, approval immutability,
validation, and cross-session isolation. Override the URL with `--url` if needed.

## Phase 2

See docs/phase3-handoff.md for routes, Finding schema, ingestion approval flow,
keyword retrieval limits and remaining embedding work. Actual outputs are recorded
in docs/phase2-verification.md. Interactive API docs for the running Phase 2
host server: http://127.0.0.1:8004/docs (use port forwarding from this cloud workspace).

## Audit repairs

See docs/phase2-repair-report.md for the audit resolutions, accepted price/MIME
formats, upload and parser resource limits, test output and remaining limitations.
Phase 2 smoke testing accepts `--url`; its default remains http://127.0.0.1:8004.

## Phase 3 reviews

POST /api/reviews/preview runs the actual LangGraph workflow. Configure server-side
OPENAI_API_KEY plus LLM_PROVIDER/LLM_MODEL and limits in .env (see .env.example).
Missing credentials produce a partial review with retained deterministic findings.
Never put provider credentials in frontend code or requests.

- docs/phase3-implementation.md — architecture, provider configuration and limits
- docs/phase3-verification.md — actual test and smoke results
- docs/phase3-frontend-contract.md — exact frontend handoff, no frontend implemented
- docs/phase3-request.schema.json and phase3-response.schema.json — generated schemas
- evaluation/phase3_cases.json — labeled fixtures, no measured model-quality metrics

The isolated Phase 3 development server is on http://127.0.0.1:8012/docs in this
workspace; use port forwarding from your computer. Run scripts/phase3_smoke.py
with --url for HTTP checks. scripts/live_llm_smoke.py --live invokes the actual
configured provider only when a credential exists, otherwise explicitly skips.

## Phase 5 judge frontend

The React app now implements the browser workflow using the existing Phase 4
API. See [frontend setup](frontend/README.md) and
[actual Phase 5 verification](docs/phase5-verification.md).

```sh
cd frontend
npm ci
npm run dev
```

The local app opens at http://localhost:5173 and proxies `/api` to port 8015 by
default. Start a migrated, seeded, isolated API with cookie demos enabled first;
full commands are in the frontend README. No public deployment is claimed.
