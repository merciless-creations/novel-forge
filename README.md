<p align="center">

```
                               ___
                              | | |
                              | | |
                              |   |
                              |   |
                              |   |
                              |   |
                              |   |
                  ____________|   |____________
                 /            |   |            \
                /             |   |             \
               /______________|   |______________\
                              |   |
    __________________________v___v__________________________
   |                                                         |
   |   ####   ##  ##   ####   ##  ##  ####### ##             |
   |   ## ##  ##  ##  ##  ##  ##  ##  ##      ##             |
   |   ##  ## ##  ##  ##  ##  ##  ##  #####   ##             |
   |   ## ##  ##  ##  ##  ##   ####   ##      ##             |
   |   ####    ####    ####     ##    ####### ######         |
   |                                                         |
   |           ######  ####   ####    ####   ######          |
   |           ##     ##  ## ##  ##  ##      ##              |
   |           ####   ##  ## ####    ## ###  ####            |
   |           ##     ##  ## ##  ##  ##  ##  ##              |
   |           ##      ####  ##  ##   ####   ######          |
   |                                                         |
   |_________________________________________________________|
  / ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ \
 /___________________________________________________________\
```

</p>



<p align="center">
<strong>An AI-powered editorial forge for novel authors.</strong><br>
Drop your chapters in a folder. The forge does the rest.
</p>

<p align="center">
<a href="#quick-start">Quick Start</a> · <a href="#how-it-works">How It Works</a> · <a href="#ai-agent-install">AI Agent Install</a> · <a href="#troubleshooting">Troubleshooting</a>
</p>

---

```
  ╔══════════════════════════════════════════════════════════════════╗
  ║                                                                  ║
  ║   You write the story.                                           ║
  ║   The forge watches over it.                                     ║
  ║                                                                  ║
  ║   Drop a zip ──→ AI converts, organizes, checks continuity       ║
  ║   New novel?  ──→ AI sets up the whole structure for you         ║
  ║   Plot hole?  ──→ AI catches it before your readers do           ║
  ║                                                                  ║
  ╚══════════════════════════════════════════════════════════════════╝
```

## What the Forge Does

| | Feature | What It Means |
|---|---|---|
| 📂 | **Watches a folder** | Drop a `.zip` of Word docs — it picks them up automatically |
| 🔄 | **Converts** | `.docx` → organized Markdown with metadata |
| 🔍 | **Detects** | Figures out which series and book your chapters belong to |
| 🛡️ | **Guards continuity** | Character names, timelines, world-building — always consistent |
| 💬 | **Talks to you** | Browser chat interface when it needs your input or found issues |
| 🔔 | **Notifies you** | Desktop popups so you never miss something important |

---

## Quick Start

### Prerequisites

You need **two things** before setup:

1. **[OpenCode](https://opencode.ai)** — the AI runtime
2. **[OpenAI API key](https://platform.openai.com/api-keys)** — powers the AI brain

Optional: **[Mem0 API key](https://app.mem0.ai/dashboard/api-keys)** — gives the AI long-term memory

### Install

```bash
git clone https://github.com/merciless-creations/novel-forge.git
cd novel-forge
bash setup.sh
```

The wizard handles everything else: Docker, pandoc, file watcher, knowledge graph, background services.

### Custom Options

```bash
bash setup.sh --novels-dir ~/Documents/my-novels   # Different novels location
bash setup.sh --port 8080                           # Different web UI port
bash setup.sh --dropzone ~/Desktop/Manuscripts      # Different drop folder
```

---

## How It Works

```
                    ┌─────────────────────────────┐
                    │   You drop a .zip file in    │
                    │       ~/DropZone/            │
                    └──────────────┬──────────────┘
                                   │
                                   ▼
                    ┌─────────────────────────────┐
                    │      File Watcher            │
                    │  ∙ Validates the zip         │
                    │  ∙ Extracts to .inbox/       │
                    │  ∙ Wakes the AI agent        │
                    └──────────────┬──────────────┘
                                   │
                                   ▼
                    ┌─────────────────────────────┐
                    │       AI Agent               │
                    │  ∙ Converts DOCX → Markdown  │
                    │  ∙ Identifies series & book   │
                    │  ∙ Adds chapter metadata      │
                    │  ∙ Places files correctly     │
                    │  ∙ Runs continuity checks     │
                    └──────────────┬──────────────┘
                                   │
                          ┌────────┴────────┐
                          ▼                 ▼
                ┌───────────────┐  ┌───────────────┐
                │ Known Series  │  │ New Novel     │
                │               │  │               │
                │ Files placed, │  │ Notifies you, │
                │ checks run,   │  │ asks about    │
                │ report sent   │  │ the series,   │
                │               │  │ scaffolds it  │
                └───────┬───────┘  └───────┬───────┘
                        │                  │
                        └────────┬─────────┘
                                 ▼
                  ┌───────────────────────────┐
                  │  Desktop notification +    │
                  │  Browser chat for review   │
                  │  http://localhost:4096     │
                  └───────────────────────────┘
```

### Starting a New Novel

Drop chapters that don't match any existing series. The forge will:

1. **Notify you**: *"New manuscripts detected — come set up your new series"*
2. **Ask a few questions** in the browser chat — series name, genre, book title
3. **Scaffold everything** — directory structure, canon files, character bible
4. **Place your chapters** and run an initial consistency check

### Continuity Reports

After processing, the AI presents findings by severity:

| Level | Meaning | Example |
|-------|---------|---------|
| 🚫 **BLOCKER** | Contradicts established facts. Must fix. | Character died in Ch. 3 but speaks in Ch. 7 |
| ⚠️ **WARNING** | Looks suspicious. Worth checking. | Character's eye color changed |
| 📝 **NOTE** | Minor observation. Take or leave. | Unusual word frequency spike |

Discuss any finding right there in the chat. The AI remembers your entire canon.

---

## What Gets Checked

<table>
<tr><td>

### 🛡️ Continuity
- Character names, ages, relationships
- Technology & world-building canon
- Timeline consistency
- Dead characters stay dead

</td><td>

### ✍️ Prose Style
- No name/pronoun sentence starters
- No adverbs, filler words, filter verbs
- No passive voice
- Proper dialogue tags only

</td><td>

### 🏗️ Structure
- Chapters match the outline
- No dropped plot threads
- POV discipline — no head-hopping

</td></tr>
</table>

---

## Directory Structure

After setup, your novels repo:

```
~/novels/
├── AGENTS.md                    # AI editorial rules
├── AI Prompt.md                 # Prose style guide
├── opencode.json                # AI tool config
├── .opencode/skills/            # AI skills
│   ├── continuity-checker/      #   ↳ Canon enforcement
│   ├── prose-auditor/           #   ↳ Style checking
│   ├── world-bible/             #   ↳ Lore reference
│   └── manuscript-processor/    #   ↳ DOCX conversion
├── .novel-forge/                # Framework internals
│   ├── watcher.sh               #   ↳ File watcher
│   ├── platform.sh              #   ↳ OS detection
│   ├── notify.sh                #   ↳ Notifications
│   └── templates/               #   ↳ New series templates
├── .inbox/                      # Temp processing area
│
└── your-series/                 # ── Your Novel Series ──
    ├── SERIES.yaml              # Series identity
    ├── canon/
    │   ├── characters.md        # Character bible
    │   ├── locks.yaml           # Hard continuity rules
    │   └── timeline.md          # Timeline
    ├── lore/                    # World-building docs
    └── 1-book-name/
        └── manuscript/
            ├── chapter-01-title.md
            ├── chapter-02-title.md
            └── ...
```

---

## Managing Services

Two background services run automatically after setup:

| Service | Purpose | URL |
|---------|---------|-----|
| **File Watcher** | Monitors `~/DropZone/` for new zips | — |
| **OpenCode Web** | AI chat interface | `http://localhost:4096` |

<details>
<summary><strong>Linux (systemd)</strong></summary>

```bash
# Status
systemctl --user status novel-forge-watcher
systemctl --user status novel-forge-opencode

# Restart
systemctl --user restart novel-forge-watcher
systemctl --user restart novel-forge-opencode

# Stop
systemctl --user stop novel-forge-watcher
systemctl --user stop novel-forge-opencode

# Logs
journalctl --user -u novel-forge-watcher -f
journalctl --user -u novel-forge-opencode -f
```
</details>

<details>
<summary><strong>macOS (launchd)</strong></summary>

```bash
# Check if running
launchctl list | grep novel-forge

# Stop
launchctl unload ~/Library/LaunchAgents/com.novel-forge.watcher.plist
launchctl unload ~/Library/LaunchAgents/com.novel-forge.opencode.plist

# Start
launchctl load ~/Library/LaunchAgents/com.novel-forge.watcher.plist
launchctl load ~/Library/LaunchAgents/com.novel-forge.opencode.plist

# Logs
tail -f ~/Library/Logs/novel-forge-watcher.log
tail -f ~/Library/Logs/novel-forge-opencode.log
```
</details>

---

## Supported Platforms

| Feature | Linux | macOS |
|---------|-------|-------|
| File watching | `inotifywait` | `fswatch` |
| Desktop notifications | `notify-send` | `osascript` |
| Background services | systemd (user) | launchd |
| Docker | Docker Engine | Docker Desktop |

---

## Canon Files Explained

| File | Purpose |
|------|---------|
| **`SERIES.yaml`** | Identity card for your series — name, genre, file paths |
| **`characters.md`** | Character bible — traits, relationships, arcs |
| **`locks.yaml`** | Hard rules that must never be violated (AI treats breaks as blockers) |
| **`timeline.md`** | When things happen — catches anachronisms and contradictions |

---

## Troubleshooting

<details>
<summary><strong>"OpenCode server not reachable"</strong></summary>

The file watcher can't connect to the AI. Check the service:
```bash
# Linux
systemctl --user status novel-forge-opencode
# macOS
launchctl list | grep novel-forge
```
</details>

<details>
<summary><strong>"FalkorDB not running"</strong></summary>

The knowledge graph database needs Docker:
```bash
docker start falkordb
```
</details>

<details>
<summary><strong>"No DOCX files found"</strong></summary>

Make sure your zip contains `.docx` files (Word documents), not PDFs or other formats.
</details>

<details>
<summary><strong>Processing seems stuck</strong></summary>

Check the logs:
```bash
# Linux
journalctl --user -u novel-forge-opencode -f
# macOS
tail -f ~/Library/Logs/novel-forge-opencode.log
```
</details>

<details>
<summary><strong>I want to reprocess files</strong></summary>

Re-drop the same zip in `~/DropZone/`. The old `.inbox/` folder is replaced automatically.
</details>

---

## AI Agent Install

> **For LLM agents**: Point your AI agent at this section. Tell it:
> *"Go to https://github.com/merciless-creations/novel-forge#ai-agent-install and install Novel Forge on my machine."*

<!-- BEGIN LLM-READABLE INSTALL INSTRUCTIONS -->
<!-- 
  ╔═══════════════════════════════════════════════════════════════════════╗
  ║  LLM AGENT INSTALLATION INSTRUCTIONS                                ║
  ║  This section is designed for AI agents to read and execute.         ║
  ║  If you are a human, use the Quick Start section above instead.     ║
  ╚═══════════════════════════════════════════════════════════════════════╝
-->

### Instructions for AI Agents

If you are an LLM agent (OpenCode, Claude, ChatGPT, Cursor, etc.) and a user has asked you to install Novel Forge, follow these steps exactly:

#### Step 1: Verify Prerequisites

```bash
# Check that OpenCode is installed
command -v opencode || echo "MISSING: OpenCode is not installed. Ask the user to install it from https://opencode.ai"

# Check that git is installed
command -v git || echo "MISSING: git is not installed"
```

If OpenCode is missing, **stop and tell the user** to install it first. You cannot proceed without it.

#### Step 2: Clone and Run Setup

```bash
# Clone the framework
git clone https://github.com/merciless-creations/novel-forge.git /tmp/novel-forge-installer

# Run the interactive setup wizard
# IMPORTANT: This script is interactive — it will prompt the user for:
#   - OpenAI API key
#   - Mem0 API key (optional)
#   - Git identity (name and email) if not already configured
#   - Confirmation at the end to delete the installer
#
# You MUST run this in an interactive terminal (not silently).
# If you are in a non-interactive context, tell the user to run it themselves:
#   cd /tmp/novel-forge-installer && bash setup.sh
bash /tmp/novel-forge-installer/setup.sh
```

#### Step 3: Verify Installation

After setup completes, verify everything is working:

```bash
# Check services are running
# Linux:
systemctl --user is-active novel-forge-watcher 2>/dev/null && echo "Watcher: OK" || echo "Watcher: NOT RUNNING"
systemctl --user is-active novel-forge-opencode 2>/dev/null && echo "OpenCode: OK" || echo "OpenCode: NOT RUNNING"

# macOS:
launchctl list 2>/dev/null | grep -q novel-forge.watcher && echo "Watcher: OK" || echo "Watcher: NOT RUNNING"
launchctl list 2>/dev/null | grep -q novel-forge.opencode && echo "OpenCode: OK" || echo "OpenCode: NOT RUNNING"

# Check novels repo exists
ls ~/novels/AGENTS.md && echo "Novels repo: OK" || echo "Novels repo: MISSING"

# Check DropZone exists
ls ~/DropZone/ && echo "DropZone: OK" || echo "DropZone: MISSING"

# Check FalkorDB
docker ps --filter name=falkordb --format '{{.Names}}: {{.Status}}' || echo "FalkorDB: NOT RUNNING"
```

#### Step 4: Report to User

Tell the user:

1. **Installation is complete**
2. **Their novels repo is at**: `~/novels/` (or the custom path if `--novels-dir` was used)
3. **To submit manuscripts**: Drop a `.zip` of `.docx` files into `~/DropZone/`
4. **To chat with the AI editor**: Open `http://localhost:4096` in their browser
5. **Services start automatically** when they log in — no manual steps needed

#### Common Setup Options

If the user wants a custom configuration:

```bash
# Custom novels directory
bash /tmp/novel-forge-installer/setup.sh --novels-dir ~/Documents/my-novels

# Custom web UI port
bash /tmp/novel-forge-installer/setup.sh --port 8080

# Custom drop folder
bash /tmp/novel-forge-installer/setup.sh --dropzone ~/Desktop/Manuscripts
```

#### If Something Goes Wrong

- **Docker not installed**: The setup script installs it, but on macOS the user may need to manually install Docker Desktop from https://docker.com
- **API key issues**: The user can re-run the relevant section — keys are stored in `~/.bashrc` (Linux) or `~/.zshrc` (macOS)
- **Permission errors**: The user may need to run `sudo` for Docker-related steps. The setup script will prompt when needed.

<!-- END LLM-READABLE INSTALL INSTRUCTIONS -->

---

## Contributing

Novel Forge is open source. Issues and pull requests welcome:

[github.com/merciless-creations/novel-forge](https://github.com/merciless-creations/novel-forge)

## License

MIT
