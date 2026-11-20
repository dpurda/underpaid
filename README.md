# Underpaid

<p align="center"><img src="assets/underpaid-logo.svg" alt="UNDERPAID · the hardest-working, lowest-paid devs you will ever hire" width="720"></p>

**The hardest-working, lowest-paid devs you will ever hire.** They work for tokens. From a ticket (or a plain description) to a reviewed, tested branch, with one command.

Underpaid is a small crew of [Claude Code](https://docs.claude.com/en/docs/claude-code) agents. Give it a ticket from Notion, Linear, Jira or GitHub Issues, or just describe the work. It plans, writes the code, tests it end to end and reviews it, then reports back (and optionally pings you on Slack or Gmail). The changes are left **uncommitted** on a new branch so you review them yourself.

```
/shipit Add export button to receivables
```

## The crew

| | Name | Role | Model |
|---|---|---|---|
| 🧭 | **Captain Kanban** | Team Lead: reads the ticket, makes the plan, coordinates the crew, reports back | your session (Opus, high effort, recommended) |
| 🛠️ | **Codey McCodeface** | Developer: makes the acceptance tests pass, never touches tests | Sonnet, high effort |
| 🐛 | **Bugsy Malone** | QA: writes the acceptance tests **before** the code, then edge cases, lint and the full suite | Opus, medium effort |
| 👀 | **Pixel Pete** | UI QA: starts the app, clicks through changed pages in a real browser, checks desktop + mobile screenshots. Only for user-visible changes | Opus, medium effort |
| 🔐 | **Lockdown Larry** | Security review. Only when the change touches auth, permissions, payments, user input, uploads or secrets | Opus, high effort |
| 🧐 | **Nitpick Nick** | Reviewer: correctness review plus `ponytail-review` for over-engineering | Opus, high effort |

## How it works

```
Ticket (Notion / Linear / Jira / GitHub) or description
   │
   ▼
🧭 Captain Kanban ── reads ticket + project notes, marks it in progress,
   │                 creates the branch (or a worktree), writes the plan
   │                 (large plans: waits for your OK)
   ▼
🐛 Bugsy Malone ── writes the acceptance tests first (they fail)
   │
   ▼
🛠️ Codey McCodeface ── implements until they pass
   │
   ▼
🐛 Bugsy Malone ── edge cases + lint + full suite ──✘──► back to Codey (max 2 rounds)
   │ ✔
   ▼
👀 Pixel Pete      (UI changes)         ┐
🔐 Lockdown Larry  (sensitive changes)  ├─ in parallel
🧐 Nitpick Nick    (always)             ┘
   │
   ▼
🛠️ Codey fixes real bugs / security / broken UI ──► 🐛 Bugsy re-runs the suite   (one round)
   │
   ▼
🧭 Captain Kanban ── writes what it learned to .claude/underpaid-notes.md
   │
   ▼
Report (terminal, + Slack or Gmail if enabled): plan, changes, tests, UI, security,
what was fixed, suggestions left for you  (nothing committed, pushed or merged)
```

**Gets better over time:** after each run the Lead adds what it learned about your project (how tests run, conventions, pitfalls) to `.claude/underpaid-notes.md`, and every run reads it first. It's plain Markdown: edit it whenever you like.

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
git clone https://github.com/dpurda/underpaid.git ~/underpaid
cd ~/path/to/your/project
~/underpaid/install.sh
```

The installer is interactive (arrow keys for choices, ←/→ or y/n for yes/no) and goes through six steps:

1. **Claude Code**: checks it's installed; offers to keep an existing config
2. **Ticketing system**: Notion, Linear, Jira, GitHub Issues or none; checks it's connected and walks you through authenticating
3. **Notifications**: Slack (checks `SLACK_WEBHOOK_URL`, can save it and send a test message), Gmail (checks the connector, asks the address, can allow sending without a prompt) or none
4. **Project settings**: test command (auto-detected for Ruby, Elixir, Rust, Go, Java/Kotlin, .NET, Swift, PHP, Python and JS package managers), lint command, base branch, plan approval (large changes / always / never), whether to work in a separate git worktree, and the command + URL that start your app (for UI QA); writes `<project>/.claude/underpaid.conf`
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
| Any frontend (React, Vue, Svelte, Angular, Astro, server-rendered views) | | `frontend-design` (UI/UX), `playwright` (browser for Pixel Pete) |

The `*-lsp` plugins need the language server on your `PATH` (the installer warns when it's missing). Codey loads the matching expert skill before writing code.

Re-running it is safe: it offers to keep your existing config (or edit `.claude/underpaid.conf` by hand for a single change), and changed files are backed up as `*.bak.<timestamp>` before being overwritten.

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
- the plan is large and `PLAN_APPROVAL` asks for your OK (or always, if set)
- your working tree isn't clean (only without a worktree; with `WORKTREE=yes` your folder is left alone)

Use `/agents` in Claude Code to see the crew.

## Update

```bash
cd ~/underpaid && git pull
cd ~/path/to/your/project && ~/underpaid/install.sh
```

## Uninstall

```sh
cd <your project> && ~/underpaid/install.sh --uninstall
```

Shows what it will remove and asks first. It removes only what Underpaid installed: `/shipit`, the agents, the project notes and UI screenshots, the stack skills and plugins it added, `.claude/underpaid.conf`, the Gmail send permission and its `.git/info/exclude` entries. Your own skills, agents and settings, `*.bak.*` backups, and anything global (shell rc, Slack webhook) are left alone.

## Layout

```
underpaid/
├── install.sh
├── README.md
├── skills/shipit/SKILL.md     # 🧭 Captain Kanban
├── agents/
│   ├── codey-mccodeface.md    # 🛠️ developer
│   ├── bugsy-malone.md        # 🐛 QA
│   ├── pixel-pete.md          # 👀 UI QA
│   ├── lockdown-larry.md      # 🔐 security review
│   └── nitpick-nick.md        # 🧐 reviewer
└── stack-skills/              # expert skills offered per detected stack
    ├── rails-expert/  elixir-expert/  rust-expert/  java-expert/
    └── typescript-expert/  react-expert/  vue-expert/  angular-expert/
```

## Configuration

Each project gets its own `.claude/underpaid.conf`:

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
PLAN_APPROVAL=large       # large | always | never
WORKTREE=no               # yes = work in a separate git worktree
APP_CMD=bin/dev           # starts the app for UI QA (empty = UI QA off)
APP_URL=http://localhost:3000
INSTALLED_SKILLS=rails-expert      # written by the installer, used by --uninstall
INSTALLED_PLUGINS=frontend-design
```

The comments above are for explanation only: in the real file, put comments on their own line, since everything after `=` is the value. Edit it by hand or re-run the installer. Project conventions (style, architecture, test layout) come from the project's own `CLAUDE.md`; every agent follows it.

## License

MIT, see [LICENSE](LICENSE).
