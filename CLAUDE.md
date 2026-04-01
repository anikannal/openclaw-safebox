# OpenClaw Safe-Box — Project Context for Claude

## What this project is

A hardened, beginner-friendly Docker distribution of [OpenClaw](https://github.com/openclaw/openclaw) — an open-source personal AI agent that users interact with over messaging apps (Telegram, Discord, Slack, WhatsApp, etc.).

**The problem we're solving:** OpenClaw's official Docker setup requires CLI expertise and ships with permissive security defaults. Non-technical users who want to experiment are stuck — they either skip it or install it unsafely with full access to their laptop's filesystem. We're building a distribution that any user with Docker Desktop can launch in under 5 minutes, with strong isolation by default.

**Project name:** OpenClaw Safe-Box
**Status:** v0.1 implementation complete. All scripts written; pending real-world test run.
**Repo:** https://github.com/YOUR_USERNAME/openclaw-safebox (update once published)
**Distribution plan:** Public GitHub repo — users either `git clone` or download the zip via GitHub's "Code → Download ZIP". No separate releases workflow needed for v1.

---

## Architecture

### Two Docker services

**`openclaw-gateway`** — The main service. Runs the OpenClaw gateway, serves the Control UI at `localhost:18789`, and maintains state in the mounted workspace volume. Stays resident.

**`openclaw-cli`** — A helper container used only during setup and channel configuration. Runs the same image, exits after each command. Users never invoke this directly — the setup script wraps it.

### Security constraints (non-negotiable)

These are the core isolation guarantees the project exists to provide. Do not relax them without explicit discussion:

- Port binding **must** be `127.0.0.1:18789:18789` — localhost only, never `0.0.0.0`
- The **only** host directory mounted is `~/openclaw-workspace` — never mount `~`, `~/Documents`, `~/.ssh`, or similar
- `read_only: true` on the container root filesystem + `tmpfs` for `/tmp`
- `cap_drop: ALL` with no capabilities added back
- `security_opt: no-new-privileges:true`
- The Docker socket (`/var/run/docker.sock`) is **never** mounted into the container
- Container runs as non-root user (`node`, UID 1000)

### Sandbox mode decision

OpenClaw has a Docker-in-Docker sandbox mode (`OPENCLAW_SANDBOX=true`) where skill/tool execution runs inside nested containers. We are **not** enabling full DinD in v1 because it requires mounting the Docker socket (which is a host root equivalent). We use process isolation only for now. Revisit in v2.

### How messaging channels work

Telegram, Discord, Slack, and WhatsApp all work via **outbound polling** — the container reaches out to their APIs, not the other way around. No inbound ports needed beyond the Control UI. This is why isolation works cleanly: the container needs outbound internet access (Docker default) and nothing else.

iMessage is **explicitly unsupported** — it requires macOS host system access which can't be safely containerized.

---

## Files to build

```
openclaw-safebox/
├── docker-compose.yml       # hardened config (primary deliverable)
├── .env.example             # template for API keys / tokens
├── setup.sh                 # Mac/Linux first-run script
├── setup.ps1                # Windows first-run script
├── add-channel.sh           # day-2 helper: add Telegram/Discord/etc
├── README.md                # plain-English user guide with screenshots
└── CLAUDE.md                # this file
```

The design doc (`OpenClaw Safe-Box — Design Doc.docx`) lives alongside this and should be treated as the source of truth for decisions made so far.

---

## Open decisions (resolve before implementation)

| Question | Options | Leaning |
|---|---|---|
| Sandbox mode | Full DinD / process isolation only / off | Process isolation only for v1 |
| Windows experience | PowerShell script / Docker Desktop extension | PowerShell + WSL2 fallback for v1 |
| Distribution | GitHub Releases zip / Docker Hub image / both | Public GitHub repo (git clone or zip via Code button) — decided |
| Auto-update | Manual pull / Watchtower / none | Prompt in setup script, no background updater |
| Upstream contribution | Yes now / yes later / standalone only | Standalone first, upstream after stable |

---

## Known CVEs to mitigate

- **CVE-2026-25253 "ClawJacked"** (CVSS 8.8) — WebSocket auth bypass on localhost instances. Mitigated by: localhost-only binding + enforcing token auth in the Control UI setup flow.
- **Prompt injection via skill input** — Mitigated by process isolation sandbox mode.

The hardened `docker-compose.yml` is the primary mitigation layer. Reference the IONOS and OpenClaw security blog guides when writing it.

---

## Target user

Someone who:
- Has Docker Desktop installed (or can follow a one-step install prompt)
- Has an Anthropic or OpenAI API key
- Has a Telegram bot token (or similar for another channel)
- Is **not** comfortable with the terminal beyond running a setup script

The setup script is the only terminal interaction required. After first run, everything goes through the browser-based Control UI at `localhost:18789`.

---

## Key constraints for implementation

- **Cross-platform:** Must work on Mac (Apple Silicon + Intel), Windows (Docker Desktop / WSL2), and Linux
- **No git required:** Users download a zip from GitHub Releases — do not assume git is installed
- **5-minute target:** From unzip to first Telegram reply in under 5 minutes for a prepared user (API keys in hand)
- **Plain-English errors:** The setup script must give human-readable error messages, not raw Docker output
- **Idempotent setup:** Running setup.sh a second time should not break an existing installation

---

## References

- [OpenClaw GitHub](https://github.com/openclaw/openclaw)
- [OpenClaw official Docker docs](https://github.com/openclaw/openclaw/blob/main/docs/install/docker.md)
- [Official docker-compose.yml](https://github.com/openclaw/openclaw/blob/main/docker-compose.yml)
- [OpenClaw security policy](https://github.com/openclaw/openclaw/security)
