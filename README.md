# Novel Forge

An AI-powered editorial assistant for novel authors. Drop your chapters in a folder, and Novel Forge converts, organizes, and checks them for continuity — automatically.

## What It Does

Novel Forge is a framework that gives you a personal AI editor. It:

- **Watches a folder** on your computer for new manuscript files
- **Converts** Word documents (.docx) to organized Markdown files
- **Detects** which novel series your chapters belong to
- **Checks** for continuity errors — character inconsistencies, timeline problems, canon violations
- **Alerts you** with desktop notifications when it finds issues or needs your input
- **Talks to you** through a browser-based chat interface

You write. It keeps track of everything.

## Prerequisites

Before running setup, you need:

1. **OpenCode** installed on your machine — [https://opencode.ai](https://opencode.ai)
2. **An OpenAI API key** — [https://platform.openai.com/api-keys](https://platform.openai.com/api-keys)
3. **A Mem0 API key** (optional, for memory features) — [https://app.mem0.ai/dashboard/api-keys](https://app.mem0.ai/dashboard/api-keys)

The setup script installs everything else (Docker, pandoc, file watcher, etc.).

## Setup

Open a terminal and run:

```bash
git clone https://github.com/merciless-creations/novel-forge.git
cd novel-forge
bash setup.sh
```

The setup wizard will:

1. Install system tools (pandoc, Docker, file watcher, notifications)
2. Set up the knowledge graph database (FalkorDB)
3. Install AI tools (MCP servers)
4. Ask for your API keys (stored securely in your shell config)
5. Create your novels repository at `~/novels/`
6. Set up background services that start automatically when you log in

### Custom Options

```bash
# Use a different directory for your novels
bash setup.sh --novels-dir ~/Documents/my-novels

# Use a different port for the web UI
bash setup.sh --port 8080

# Use a different folder for dropping manuscripts
bash setup.sh --dropzone ~/Desktop/Manuscripts
```

## How to Use

### The Basic Workflow

1. **Export your chapters** from your writing software (Word, Scrivener, etc.) as `.docx` files
2. **Put them in a `.zip` file** — name the zip something descriptive like `"Skyfire Chapters 1-10.zip"`
3. **Drop the zip** into `~/DropZone/` (or wherever you configured it)
4. **Wait for the notification** — you'll get a desktop popup when processing is done
5. **Open your browser** to `http://localhost:4096` to review the results

### What Happens Behind the Scenes

When you drop a zip file:

```
You drop "Skyfire Chapters 1-10.zip" in ~/DropZone/
    |
    v
File watcher picks it up
    |
    v
Extracts to ~/novels/.inbox/Skyfire Chapters 1-10/
    |
    v
AI agent wakes up and:
  - Converts all DOCX files to Markdown
  - Figures out these belong to "Of Salt and Starlight" → "Skyfire"
  - Adds metadata (chapter number, title, word count)
  - Places files in the right directory
  - Runs continuity checks
    |
    v
Desktop notification: "Processed 10 chapters. 1 issue found."
    |
    v
Open browser to review and chat with the AI about any issues
```

### Starting a New Novel

If you drop chapters that don't match any existing series, Novel Forge will:

1. Send you a notification: "New manuscripts detected — come set up your new series"
2. When you open the browser, it will ask you a few questions:
   - What's the series name?
   - What genre is it?
   - What's the book title?
   - What time period does it cover?
3. It creates the full directory structure and canon files for you
4. Places your chapters and runs an initial consistency check

### Reviewing Continuity Reports

After processing, the AI presents a report in the browser chat:

- **BLOCKER** — Something that contradicts your established facts. Must be fixed.
- **WARNING** — Something that looks suspicious. Worth checking.
- **NOTE** — Minor observation. Take it or leave it.

You can discuss any finding with the AI right there in the chat.

## Directory Structure

After setup, your novels repository looks like this:

```
~/novels/
├── AGENTS.md                  # Rules the AI follows
├── AI Prompt.md               # Your prose style rules
├── opencode.json              # AI tool configuration
├── .opencode/skills/          # AI skills (continuity, prose, etc.)
├── .novel-forge/              # Framework support files
│   ├── templates/             # Templates for new series
│   ├── watcher.sh             # File watcher script
│   ├── platform.sh            # OS detection
│   └── notify.sh              # Notification helpers
├── .inbox/                    # Temporary processing area
└── my-series-name/            # Your novel series
    ├── SERIES.yaml            # Series manifest
    ├── canon/
    │   ├── characters.md      # Character bible
    │   ├── locks.yaml         # Hard continuity rules
    │   └── timeline.md        # Series timeline
    ├── lore/                  # World-building documents
    └── 1-book-name/
        └── manuscript/
            ├── chapter-01-title.md
            ├── chapter-02-title.md
            └── ...
```

## Managing Services

Novel Forge runs two background services:

1. **File watcher** — watches `~/DropZone/` for new zip files
2. **OpenCode web server** — the AI chat interface at `http://localhost:4096`

### Linux (systemd)

```bash
# Check status
systemctl --user status novel-forge-watcher
systemctl --user status novel-forge-opencode

# Restart
systemctl --user restart novel-forge-watcher
systemctl --user restart novel-forge-opencode

# Stop
systemctl --user stop novel-forge-watcher
systemctl --user stop novel-forge-opencode

# View logs
journalctl --user -u novel-forge-watcher -f
journalctl --user -u novel-forge-opencode -f
```

### macOS (launchd)

```bash
# Check if running
launchctl list | grep novel-forge

# Stop
launchctl unload ~/Library/LaunchAgents/com.novel-forge.watcher.plist
launchctl unload ~/Library/LaunchAgents/com.novel-forge.opencode.plist

# Start
launchctl load ~/Library/LaunchAgents/com.novel-forge.watcher.plist
launchctl load ~/Library/LaunchAgents/com.novel-forge.opencode.plist

# View logs
tail -f /tmp/novel-forge-watcher.log
tail -f /tmp/novel-forge-opencode.log
```

## Supported Platforms

| Feature | Linux | macOS |
|---------|-------|-------|
| File watching | inotifywait | fswatch |
| Desktop notifications | notify-send | osascript |
| Background services | systemd (user) | launchd |
| Docker | Docker Engine | Docker Desktop |

## What the AI Checks

### Continuity
- Character names, ages, and relationships stay consistent
- Technology and world-building details match your canon
- Timeline references don't contradict earlier chapters
- Dead characters don't reappear

### Prose Style
- No sentences starting with character names or pronouns
- No adverbs (-ly words)
- No filler words (just, then, even, seemed, very, really)
- No sensory filter verbs (felt, heard, noticed, saw)
- No passive voice
- Proper dialogue tags (only "said" and "asked")
- No cliched phrases

### Structure
- Chapters match the master outline (if one exists)
- No dropped plot threads
- POV discipline — no head-hopping

## Troubleshooting

### "OpenCode server not reachable"
The file watcher couldn't connect to the AI. Check if the OpenCode service is running:
```bash
# Linux
systemctl --user status novel-forge-opencode
# macOS
launchctl list | grep novel-forge
```

### "FalkorDB not running"
The knowledge graph database needs Docker:
```bash
docker start falkordb
```

### "No DOCX files found"
Make sure your zip contains `.docx` files (Word documents), not PDFs or other formats.

### Processing seems stuck
Check the OpenCode logs:
```bash
# Linux
journalctl --user -u novel-forge-opencode -f
# macOS
tail -f /tmp/novel-forge-opencode.log
```

### I want to reprocess files
If something went wrong, you can re-drop the same zip in `~/DropZone/`. The old `.inbox/` folder will be replaced automatically.

## Canon Files Explained

### SERIES.yaml
The "identity card" for your series. Tells the AI what your series is called, what genre it is, and where to find all the related files.

### characters.md
Your character bible. Who they are, their traits, relationships, and arcs. The AI uses this to check consistency.

### locks.yaml
Hard rules that must never be violated. Things like "Character X's AI companion is always called ORPHEUS" or "Character Y is 22 years old." The AI treats violations of these as blockers.

### timeline.md
When things happen. The AI uses this to catch anachronisms and timeline contradictions.

## Contributing

Novel Forge is open source. Issues and pull requests welcome at:
[https://github.com/merciless-creations/novel-forge](https://github.com/merciless-creations/novel-forge)

## License

MIT
