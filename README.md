# OpenClaw Safe-Box 🦞

Run [OpenClaw](https://github.com/openclaw/openclaw) on your own laptop — safely, in under 5 minutes.

OpenClaw is a personal AI assistant you talk to over the messaging apps you already use (Telegram, Discord, Slack, WhatsApp). Safe-Box is a pre-configured version that locks it inside a security container, so it can't touch your files, your SSH keys, or anything else on your machine unless you explicitly put it in a dedicated workspace folder.

> **Not affiliated with the OpenClaw project.** This is an unofficial community distribution focused on safe, beginner-friendly local installation.

---

## What you'll need

Before you start, have these three things ready:

- **Docker Desktop** — free, runs on Mac, Windows, and Linux. [Download it here](https://www.docker.com/products/docker-desktop). After installing, open it and wait for the whale icon to stop animating.
- **An AI API key** — either [Anthropic (Claude)](https://console.anthropic.com/settings/keys) or [OpenAI (GPT)](https://platform.openai.com/api-keys). Anthropic is recommended.
- **A messaging channel token** — the easiest is a Telegram bot token (see [Getting a Telegram bot token](#getting-a-telegram-bot-token) below). You can add more channels later.

---

## Getting started

### Mac or Linux

Open Terminal and run:

```bash
curl -fsSL https://raw.githubusercontent.com/anikannal/openclaw-safebox/main/install.sh | bash
```

That's it. The installer checks your Docker setup, downloads the Safe-Box files to `~/openclaw-safebox`, and walks you through configuration. Your browser will open automatically when it's done.

<details>
<summary>Don't want to pipe to bash? Click here for alternatives.</summary>

**Download and inspect first (recommended for the cautious):**
```bash
curl -fsSL https://raw.githubusercontent.com/anikannal/openclaw-safebox/main/install.sh -o install.sh
# Read install.sh, then:
bash install.sh
```

**With git:**
```bash
git clone https://github.com/anikannal/openclaw-safebox.git ~/openclaw-safebox
~/openclaw-safebox/setup.sh
```

**Without git or curl:** click the green **Code** button → **Download ZIP**, unzip it, open Terminal in that folder and run `./setup.sh`.

</details>

### Windows

Open **PowerShell** (search for it in the Start menu — not Command Prompt) and run:

```powershell
irm https://raw.githubusercontent.com/anikannal/openclaw-safebox/main/install.ps1 | iex
```

> If you see "scripts are disabled", run this first, then try again:
> `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`

The installer checks Docker, downloads the Safe-Box files to `~\openclaw-safebox`, and walks you through configuration.

<details>
<summary>Prefer not to pipe to iex? Click here for alternatives.</summary>

**Download and inspect first:**
```powershell
irm https://raw.githubusercontent.com/anikannal/openclaw-safebox/main/install.ps1 -OutFile install.ps1
# Read install.ps1, then:
.\install.ps1
```

**With git:**
```powershell
git clone https://github.com/anikannal/openclaw-safebox.git ~\openclaw-safebox
~\openclaw-safebox\setup.ps1
```

**Without git:** click the green **Code** button → **Download ZIP**, unzip it, open PowerShell in that folder and run `.\setup.ps1`.

</details>

---

## Getting a Telegram bot token

Telegram is the easiest channel to set up. Here's how to create a bot:

1. Open Telegram on your phone or computer and search for **@BotFather**
2. Start a conversation and send the message: `/newbot`
3. BotFather will ask you for a name (what your bot is called, like "My Assistant") and a username (must end in `bot`, like `myassistant_bot`)
4. It will give you a token that looks like `123456789:ABCdefGHIjklMNOpqrSTUvwxYZ`
5. Paste that token when `setup.sh` / `setup.ps1` asks for it

Once setup is done, find your bot in Telegram and say hello. It will respond through OpenClaw.

---

## Your workspace folder

OpenClaw can only access **one folder** on your computer: `~/openclaw-workspace` (on Mac/Linux) or `C:\Users\YourName\openclaw-workspace` (on Windows). You can choose a different location during setup.

This means:

- ✅ Files you put in that folder, OpenClaw can read
- ✅ Documents OpenClaw creates will appear there
- ❌ Everything else on your machine — your Documents, Downloads, Desktop, code, photos — is completely blocked

You can open this folder in Finder or File Explorer at any time to see what OpenClaw has been working on.

---

## Adding more channels

After the initial setup, you can connect additional messaging channels using the helper script:

**Mac / Linux:**
```
./add-channel.sh telegram
./add-channel.sh discord
./add-channel.sh slack
./add-channel.sh whatsapp
```

**Windows:**
```
.\add-channel.ps1 telegram
.\add-channel.ps1 discord
.\add-channel.ps1 slack
.\add-channel.ps1 whatsapp
```

The script will walk you through where to get the token for each service.

### Channel notes

**Discord** — You'll need to create a bot at [discord.com/developers](https://discord.com/developers/applications) and enable the "Message Content Intent" permission. The script explains each step.

**Slack** — Slack needs two tokens: a bot token (starts with `xoxb-`) and an app-level token (starts with `xapp-`). The script explains how to get both.

**WhatsApp** — Instead of a token, WhatsApp uses a QR code scan. The script will display a QR code; scan it with your phone via WhatsApp → Settings → Linked Devices. Note that WhatsApp may disconnect after long periods of inactivity — just run the script again to re-pair.

---

## Day-to-day use

### Starting and stopping OpenClaw

After the initial setup, OpenClaw starts automatically when Docker Desktop opens. You can also control it manually:

| What you want to do | Command |
|---|---|
| Start OpenClaw | `docker compose up -d` |
| Stop OpenClaw | `docker compose stop` |
| Restart OpenClaw | `docker compose restart` |
| See what's happening | `docker compose logs -f openclaw-gateway` |

You can also start and stop it from the Docker Desktop app — find `openclaw-gateway` in the Containers list and use the play/stop buttons.

### Updating to the latest version

```
docker compose pull
docker compose up -d
```

This pulls the latest OpenClaw image and restarts the gateway. Your configuration, channel connections, and workspace files are all preserved.

### Opening the Control UI

Visit `http://localhost:18789` in your browser at any time. You'll need your gateway token, which is saved in the `.env` file in the Safe-Box folder.

### Full reset (start from scratch)

```
docker compose down -v
```

This stops and removes all containers and deletes OpenClaw's internal configuration (channel connections, gateway token). Your `~/openclaw-workspace` folder is **not** deleted — those files stay on your machine.

---

## Security: what this protects you from

OpenClaw is powerful software — it can browse the web, write code, and manage files on your behalf. The Safe-Box configuration is designed to limit what it can reach if something goes wrong.

**What's blocked:**

- Your home directory, Documents, Downloads, Desktop, and all other folders
- Your SSH keys, credentials, and config files
- Your Docker setup (the Docker socket is not exposed)
- Any inbound connections from your local network

**What's allowed:**

- The `~/openclaw-workspace` folder only
- Outbound internet access (so it can talk to Telegram, Anthropic's API, etc.)
- The Control UI at `localhost:18789` — accessible only from your own machine

**What this doesn't protect against:**

Docker containers share the same operating system kernel as your machine. A very sophisticated attacker with code execution inside the container could theoretically escape via an unpatched kernel vulnerability. This is rare in practice, but if you're working with highly sensitive data, use a dedicated virtual machine or a separate physical device instead — which is what OpenClaw's own documentation recommends.

For everyday experimentation, the Safe-Box configuration is a significant improvement over running OpenClaw directly on your machine with full access to everything.

---

## Troubleshooting

### "Docker is not running"

Open Docker Desktop from your Applications folder (Mac) or Start menu (Windows) and wait for it to fully start (the whale icon in the menu bar / system tray stops animating). Then try again.

### The setup script said it succeeded but my bot isn't responding

1. Check that OpenClaw is running: `docker compose ps`
2. Look at the logs for errors: `docker compose logs --tail=50 openclaw-gateway`
3. Make sure your bot token is correct — go back to @BotFather on Telegram and use `/mybots` to check
4. Try sending `/start` to your bot first; some bots require this before they'll respond

### "Error: gateway token mismatch" when adding a channel

The token in your `.env` file doesn't match what the gateway is using. Re-run setup to regenerate and sync them:
```
./setup.sh       # Mac/Linux
.\setup.ps1      # Windows
```

### The Control UI shows a blank page or won't load

The gateway may still be starting up. Wait 30 seconds and refresh. If it still doesn't load:
```
docker compose logs --tail=50 openclaw-gateway
```
Look for any error messages and check the OpenClaw GitHub issues if you're unsure what they mean.

### WhatsApp disconnected

This is normal — WhatsApp's linked device connection expires after a period of inactivity. Re-pair it:
```
./add-channel.sh whatsapp       # Mac/Linux
.\add-channel.ps1 whatsapp      # Windows
```

### I need to change my API key

Open `.env` in a text editor, update the relevant line, then restart:
```
docker compose restart openclaw-gateway
```

### Something else is wrong

Check the full logs first — they usually tell you what happened:
```
docker compose logs openclaw-gateway
```

If you're stuck, open an issue on the [OpenClaw Safe-Box GitHub repository](https://github.com/anikannal/openclaw-safebox/issues) or check the [OpenClaw community forums](https://github.com/openclaw/openclaw/discussions).

---

## File reference

| File | Purpose |
|---|---|
| `docker-compose.yml` | Defines the containers and all security settings |
| `.env` | Your API keys and tokens (created by setup — never commit this) |
| `.env.example` | Template showing all available settings |
| `setup.sh` / `setup.ps1` | First-run setup script |
| `add-channel.sh` / `add-channel.ps1` | Add a new messaging channel |
| `~/openclaw-workspace/` | The only folder OpenClaw can access on your machine |

---

## Acknowledgements

OpenClaw Safe-Box is an unofficial, community-built distribution of [OpenClaw](https://github.com/openclaw/openclaw) by Peter Steinberger. It is not affiliated with or endorsed by the OpenClaw project. All credit for OpenClaw itself goes to the OpenClaw team and contributors.
