# Shipyard

<p align="center"><img src="assets/logo.svg" alt="SHIPYARD · your best team" width="760"></p>

**From ticket (or a plain description) to a reviewed, tested branch, with one command.**

Shipyard is a small crew of [Claude Code](https://docs.claude.com/en/docs/claude-code) agents. Give it a ticket from Notion, Linear, Jira or GitHub Issues, or just describe the work. It plans, writes the code, tests it end to end and reviews it, then reports back (and optionally pings you on Slack or Gmail). The changes are left **uncommitted** on a new branch so you review them yourself.

```
/shipit Add export button to receivables
```

## The crew

| | Name | Role | Model |
|---|---|---|---|
| 🧭 | **Captain Kanban** | Team Lead: reads the ticket, makes the plan, coordinates the crew, reports back | your session (Opus, high effort, recommended) |
| 🛠️ | **Codey McCodeface** | Developer: implements the plan, never touches existing tests | Sonnet, high effort |
| 🐛 | **Bugsy Malone** | QA: writes specs for the acceptance criteria, runs lint and the full suite | Opus, medium effort |
| 🧐 | **Nitpick Nick** | Reviewer: read-only correctness review plus `ponytail-review` for over-engineering | Opus, high effort |

## How it works

```
Ticket (Notion / Linear / Jira / GitHub) or description
   │
   ▼
🧭 Captain Kanban ── checks ticket, marks it in progress, creates branch, writes the plan
   │
   ▼
🛠️ Codey McCodeface ── implements the plan
   │
   ▼
🐛 Bugsy Malone ── tests + lint + full suite ──✘──► back to Codey (max 2 rounds)
   │ ✔
   ▼
🧐 Nitpick Nick ── review: Correctness + Over-engineering
   │
   ▼
Report (terminal, + Slack or Gmail if enabled): plan, changes, tests, review suggestions
(nothing committed, pushed or merged; you decide)
```

When the work is deployed, tell Captain Kanban, e.g. *"the ticket X is in production, PR https://github.com/.../pull/123"*. It closes the ticket (status, PR link and a short write-up).

## Requirements

- **Claude Code** (works with a Claude Max subscription)
- Optional: a **ticketing system** connected to Claude Code: Notion, Linear or Jira (MCP connector), or GitHub Issues (`gh` CLI). Without one, `/shipit` takes a plain description.
- Optional notifications: a **Slack** incoming webhook in `SLACK_WEBHOOK_URL`, or the **Gmail** connector (claude.ai → Settings → Connectors). Without either, the report shows in the terminal only.
- A **git** repository (any language or framework: Rails, Elixir, Rust, Java/Kotlin, JS/TS, React, Vue, Angular, Python, Go, PHP, C#, Swift…)
- A test suite command that works locally (e.g. `bin/rspec`, `mix test`, `cargo test`, `npm test`, or a docker wrapper)
- Recommended: a project `CLAUDE.md` with your conventions (run `/init` in Claude Code to generate one)
- Optional: the `ponytail` plugin; Nitpick Nick skips it if missing

## Install

Run the installer from **the project you want to use it in**:

```bash
git clone https://github.com/dpurda/shipyard.git ~/shipyard
cd ~/path/to/your/project
~/shipyard/install.sh
```

The installer is interactive (arrow keys for choices, ←/→ or y/n for yes/no) and goes through six steps:

1. **Claude Code**: checks it's installed; offers to keep an existing config
2. **Ticketing system**: Notion, Linear, Jira, GitHub Issues or none; checks it's connected and walks you through authenticating
3. **Notifications**: Slack (checks `SLACK_WEBHOOK_URL`, can save it and send a test message), Gmail (checks the connector, asks the address, can allow sending without a prompt) or none
4. **Project settings**: test command (auto-detected for Ruby, Elixir, Rust, Go, Java/Kotlin, .NET, Swift, PHP, Python and JS package managers), lint command and base branch; writes `<project>/.claude/shipyard.conf`
5. **Stack skills**: detects the stack and offers what makes the crew better at it (see below)
6. **Install**: copies the skill, agents and chosen stack skills into `<project>/.claude/`, adds them to `.git/info/exclude` so they **never end up in the project's commits** (your `.gitignore` is not touched), and offers to move old global `shipit` / `ticket-to-pr` skills out of the way

### Stack skills

Each suggestion is a yes/no question; anything already installed is skipped.

| Detected | Expert skill (bundled, copied into `.claude/skills/`) | Official plugin (installed for this project only) |
|---|---|---|
| Rails / Ruby | `rails-expert` | `ruby-lsp` |
| Elixir / Phoenix | `elixir-expert` | |
| Rust | `rust-expert` | `rust-analyzer-lsp` |
| Java / Kotlin | `java-expert` | `jdtls-lsp`, `kotlin-lsp` |
| JS / TS / Node | `typescript-expert` | `typescript-lsp` |
| React / Next | `react-expert` | |
| Vue / Nuxt | `vue-expert` | |
| Angular | `angular-expert` | |
| Python, Go, PHP, C#, Swift | | `pyright-lsp`, `gopls-lsp`, `php-lsp`, `csharp-lsp`, `swift-lsp` |
| Any frontend (React, Vue, Svelte, Angular, Astro, server-rendered views) | | `frontend-design` (UI/UX) |

The `*-lsp` plugins need the language server on your `PATH` (the installer warns when it's missing). Codey loads the matching expert skill before writing code.

Re-running it is safe: it offers to keep your existing config (or edit `.claude/shipyard.conf` by hand for a single change), and changed files are backed up as `*.bak.<timestamp>` before being overwritten.

## Usage

```bash
cd ~/path/to/your/project   # clean working tree
claude
/model opus                 # recommended for Captain Kanban
/effort high
/shipit <ticket title or ID>        # or, without ticketing: /shipit <description>
```

Captain Kanban stops and tells you when:

- no ticket, or more than one, matches
- the ticket already has a PR
- the ticketing tool isn't connected
- the ticket is too vague (it lists the questions)
- your working tree isn't clean

Use `/agents` in Claude Code to see the crew.

## Update

```bash
cd ~/shipyard && git pull
cd ~/path/to/your/project && ~/shipyard/install.sh
```

## Uninstall

```sh
cd <your project> && ~/shipyard/install.sh --uninstall
```

Shows what it will remove and asks first. It removes only what Shipyard installed: `/shipit`, the three agents, the stack skills and plugins it added, `.claude/shipyard.conf`, the Gmail send permission and its `.git/info/exclude` entries. Your own skills, agents and settings, `*.bak.*` backups, and anything global (shell rc, Slack webhook) are left alone.

## Layout

```
shipyard/
├── install.sh
├── README.md
├── skills/shipit/SKILL.md     # 🧭 Captain Kanban
├── agents/
│   ├── codey-mccodeface.md    # 🛠️ developer
│   ├── bugsy-malone.md        # 🐛 QA
│   └── nitpick-nick.md        # 🧐 reviewer
└── stack-skills/              # expert skills offered per detected stack
    ├── rails-expert/  elixir-expert/  rust-expert/  java-expert/
    └── typescript-expert/  react-expert/  vue-expert/  angular-expert/
```

## Configuration

Each project gets its own `.claude/shipyard.conf`:

```ini
TICKETS=notion            # notion | linear | jira | github | none
BOARD=collection://...    # Notion data source, Linear team key, Jira project key, or owner/repo
STATUS_IN_PROGRESS=In progress
STATUS_DONE=Done
PR_FIELD=PR               # Notion only: property for the PR link (empty = skip)
NOTES_FIELD=              # Notion only: property for a one-line result note (empty = skip)
NOTIFY=slack              # slack | gmail | none
NOTIFY_TO=                # gmail: address to email the report to
BASE_BRANCH=main
TEST_CMD=bin/rspec
LINT_CMD=                 # empty = QA finds the project's linter
INSTALLED_SKILLS=rails-expert      # written by the installer, used by --uninstall
INSTALLED_PLUGINS=frontend-design
```

The comments above are for explanation only: in the real file, put comments on their own line, since everything after `=` is the value. Edit it by hand or re-run the installer. Project conventions (style, architecture, test layout) come from the project's own `CLAUDE.md`; every agent follows it.

## License

MIT, see [LICENSE](LICENSE).
