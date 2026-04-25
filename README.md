# Frappe Desk

A local-only control panel for managing Frappe / ERPNext benches, sites, apps, backups, and long-running `bench` commands — with a live-streaming terminal baked into the UI.

Inspired by the "Viv Desk Tool" reference design. Rebuilt from scratch as **Frappe Desk** so you can drop it into Claude Code and extend it freely.

---

## Install — one command

After unzipping the project, **one command** does everything:

```bash
cd ~/frappe_desk && bash install.sh
```

This installs the panel itself (Python venv + Flask), starts it as a background daemon, and opens it in your browser. **Frappe's own dependencies — MariaDB, Redis, Node, bench, uv, etc. — install from the web UI by clicking buttons** on the Requirements page. No more bootstrap scripts that cascade-fail.

### Windows 11 (fresh machine)

Open **PowerShell as Administrator** once to install WSL2:
```powershell
wsl --install -d Ubuntu-24.04
```
Reboot. On first launch, set a Linux username/password.

Then drop `frappe_desk.zip` into your Linux home (Explorer → `\\wsl.localhost\Ubuntu-24.04\home\<you>\`) and inside Ubuntu:

```bash
cd ~ && unzip frappe_desk.zip -d frappe_desk && cd frappe_desk && bash install.sh
```

When the script finishes, your default browser opens automatically to `http://127.0.0.1:5050/`.

### macOS / Linux

```bash
unzip frappe_desk.zip -d frappe_desk && cd frappe_desk && bash install.sh
```

### After the panel is running

Click **Requirements** in the sidebar. There's a numbered checklist of what Frappe needs:
1. MariaDB (auto-configures root password + auth plugin)
2. Redis
3. Node.js 24
4. Yarn
5. wkhtmltopdf
6. Python 3.14 *(required by Frappe v16)*
7. Python 3.10 *(only if you want v15 benches)*
8. uv *(Python package manager, required by bench)*
9. bench CLI

Click **Install** on each in order. Each runs as a streaming job — you see exactly what's happening. After installing **MariaDB**, **Node**, or **uv**, restart the panel from your terminal so the new tools are visible:

```bash
./frappe-desk stop && ./frappe-desk start
```

Once everything is **Installed**, go to **Benches → + New Bench** to scaffold your first Frappe bench. Then **Sites → + New Site** to spin up a Frappe instance. Click **Open ↗** on the bench row to jump to your site in the browser.

---

## What it does

- **Benches**: create (with Python-version and Frappe-branch selection), start, kill, sync-from-disk, get-app, build.
- **Sites**: create (one-click DB bootstrap), set default, reset admin password, toggle developer mode, migrate, clear cache, install app, backup/restore, drop.
- **Jobs**: every long-running `bench` command runs in a background worker thread, streams stdout/stderr live via Server-Sent Events to the UI, and persists a log tail for reload.
- **Live terminal UI** inside the browser — no need to tail logs in a separate terminal.
- **Masking** of `--db-root-password` / `--admin-password` in displayed commands and streamed logs.
- **Requirements** page — quick sanity check of `bench`, `node`, `mariadb`, `redis`, etc.
- **Server Log** page — tails `panel-server.log` when running in background.

---

## Architecture

```
frappe_desk/
├── app.py                     # Entry point; starts Flask + worker thread
├── frappe-desk                # CLI (start/stop/status/logs)
├── run.sh / run-background.sh / stop-background.sh
├── setup-frappe-desk-command.sh
├── requirements.txt
├── .env.example  .flaskenv  .gitignore
└── control_panel/
    ├── __init__.py            # App factory
    ├── config.py              # Reads .env; holds interpreter map + paths
    ├── extensions.py          # db = SQLAlchemy()
    ├── models.py              # Bench / Site / Job
    ├── routes/
    │   ├── views.py           # HTML pages (templates)
    │   ├── api.py             # JSON API consumed by the JS
    │   └── stream.py          # SSE endpoint for live job logs
    ├── services/
    │   ├── worker.py          # Queue + thread runner + subscriber fanout
    │   ├── bench_ops.py       # Bench lifecycle (create/start/kill/sync)
    │   └── site_ops.py        # Site lifecycle + backup/restore/drop
    ├── templates/             # Jinja2 (benches.html, sites.html, job_detail.html, …)
    └── static/
        ├── css/style.css
        └── js/ (common, benches, sites, jobs, job_detail)
```

**Storage**
- `panel.sqlite3` — the panel's own state (benches, sites, jobs, log tails). Completely separate from Frappe's site databases.
- `BENCHES_ROOT` — the directory you already use for `bench init` (defaults to `~/frappe-benches`).

**Background jobs**
- A single daemon thread pulls from an in-memory queue.
- Each job spawns a subprocess with a fresh process group (for clean kill).
- Output lines are fanned out to any number of SSE subscribers *and* appended to a rolling tail in the DB, so reloading the job page shows history.
- `[panel] ...` preamble lines announce what's about to happen (mirroring the reference UI).

**Security / safety**
- Passwords in commands are replaced with `<MARIADB_ROOT_PASSWORD>` / `<ADMIN_PASSWORD>` for display.
- Streamed log lines pass through a regex masker that redacts `--password`, `token=`, etc.
- The panel binds to `127.0.0.1` by default — do not expose it to the internet without authentication in front.

---

## Setup

```bash
# 1. Clone or copy this folder, then:
cd frappe_desk

# 2. Create a virtualenv and install deps
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 3. Configure
cp .env.example .env
# then edit BENCHES_ROOT and passwords as needed

# 4. (Optional) put `frappe-desk` on PATH
bash setup-frappe-desk-command.sh

# 5. Start the panel
./frappe-desk start           # foreground, Ctrl-C to stop
# or
./frappe-desk start --bg      # background; logs to panel-server.log
```

Then open **http://127.0.0.1:5050/**.

First run? Go to **Benches → Sync disk** to pick up any benches you already have under `BENCHES_ROOT`.

---

## Using it in Claude Code

Open the folder in Claude Code and iterate freely. The codebase is intentionally small and well-separated:

- Add a new action → a method in `services/site_ops.py` + a route in `routes/api.py` + a button in `templates/sites.html` + a handler in `static/js/sites.js`.
- Add a new page → a template + a route in `routes/views.py` + a nav entry in `templates/base.html`.
- Add a new job type → just call `enqueue_job(action, title, command, cwd=…)` from anywhere in the services layer.

---

## CLI reference

```
frappe-desk start              # run foreground
frappe-desk start --bg         # run background
frappe-desk stop               # stop background instance
frappe-desk status             # show status
frappe-desk logs               # tail panel-server.log
```

Environment overrides: `PORT`, `HOST`, `FRAPPE_DESK_PYTHON`.

---

## Roadmap ideas (deliberately not implemented — yours to tailor)

- Per-user auth (e.g. simple basic-auth in front)
- Websocket instead of SSE (fine for LAN; SSE is one-way but trivial to deploy)
- Celery/RQ if you need multi-worker parallelism
- Docker Compose profile
- Role-based "read-only" mode for demos
