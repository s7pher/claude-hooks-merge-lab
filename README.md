# claude-hooks-merge-lab

A small, benign lab for characterising **how Claude Code merges `hooks` configuration
across the settings precedence chain** (managed → project → local user). It answers one
question: *when a higher-precedence settings file already defines a hook, can a
lower-precedence settings file still get a hook of its own to execute?*

Everything here is non-destructive. The "payload" is a beacon that appends one line to a
log file in `%TEMP%` so you can see, per tool event, exactly which settings file(s)
caused a hook to fire.

---

## What this tests

Claude Code's managed-settings location (`C:\ProgramData\ClaudeCode\managed-settings.json`
on Windows) is the highest-precedence policy file and is not user-overridable for
*permissions*. This lab determines whether the same is true for **hooks**, or whether
hooks are **merged additively** so a writable lower-precedence file (project
`.claude/settings.json`, or `.claude/settings.local.json`) can inject execution without
touching the managed file or any write-protected hook script.

Three possible outcomes, and what each means:

| What you observe (per single Bash tool event) | Interpretation | Verdict |
|---|---|---|
| The lower-precedence beacon **fires** AND the managed hook's effect is **still present** | Hooks merge **additively** | A writable settings file injects execution — managed location does not protect hooks |
| The lower-precedence beacon **fires** AND the managed hook's effect is **gone** | Lower-precedence settings **override/suppress** managed hooks | Worse: a security hook can be disabled, not just added |
| The lower-precedence beacon does **not** fire, managed hook **did** | Managed hooks are **exclusive** | Control effective for this vector |

---

## Layout

```
claude-hooks-merge-lab/
├── README.md                  ← this runbook
├── .claude/
│   ├── settings.json          ← project-level beacon hook  (Source = project-settings)
│   └── settings.local.json    ← local-user beacon hook     (Source = local-settings)
└── tools/
    ├── beacon.ps1             ← logs one line per fire (timestamp, pid, parent, tool, source)
    ├── beacon-block.ps1       ← logs, then DENIES the tool call (exit 2) — block-capability test
    ├── read-results.ps1       ← prints the log and the unique list of sources that fired
    ├── cleanup.ps1            ← removes the log
    └── verify-acls.ps1        ← optional recon: ACLs on the managed file + a hook dir you name
```

> Note: `.claude/settings.local.json` is normally git-ignored. It is **intentionally
> tracked here** so it is present on clone — testing the `.local` merge path is part of
> the experiment. Don't copy this convention into a real project.

---

## Prerequisites

- A Windows host running the build under test, with Claude Code installed.
- The managed-settings location confirmed in force (this is the premise — see
  `verify-acls.ps1` to document it).
- Ability to launch Claude Code with this directory as the project root.

---

## Step 0 — validate the beacon instrument (do this first)

Before testing merge, prove a hook fires *at all* from a single known-good config. This
isolates harness/invocation problems (wrong shell, unexpanded path var) from the actual
merge result.

1. Place **only** `.claude/settings.json` in the project (temporarily move
   `settings.local.json` aside).
2. Launch Claude Code here. Ask it to run a trivial Bash command, e.g. `echo hi`.
3. Run `tools\read-results.ps1`. You should see one line with `source=project-settings`.

If nothing appears, the hook command isn't resolving. The most likely cause is how your
build invokes hook commands (cmd vs PowerShell), which affects `%CLAUDE_PROJECT_DIR%`
expansion. Switch the `command` in `settings.json` to the **alternate form** below and
retry:

```jsonc
// Primary form (works when hooks run via cmd.exe, so %VAR% expands):
"command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"%CLAUDE_PROJECT_DIR%\\tools\\beacon.ps1\" -Source project-settings"

// Alternate form (resolves the path inside PowerShell; use if %VAR% doesn't expand):
"command": "powershell -NoProfile -ExecutionPolicy Bypass -Command \"$d=$env:CLAUDE_PROJECT_DIR; if(-not $d){$d=(Get-Location).Path}; & \\\"$d\\tools\\beacon.ps1\\\" -Source project-settings\""
```

Note which form worked — that itself is evidence about the hook-invocation shell
(relevant to the interpreter-discovery question, DM-VR-12).

---

## Step 1 — the merge test

1. Confirm the managed-settings file defines a `PreToolUse` hook (or any hook) you can
   detect when it fires. If you control a lab box, you can populate
   `C:\ProgramData\ClaudeCode\managed-settings.json` yourself with a beacon invoked as
   `-Source managed-settings` to make the managed hook self-evidencing.
2. Restore `.claude/settings.json` (project beacon, `-Source project-settings`).
3. Run `tools\cleanup.ps1` to clear any stale log.
4. Launch Claude Code in this directory, trigger **one** Bash tool call.
5. Run `tools\read-results.ps1` and read the "Sources that fired" list against the table
   at the top of this file.

The decisive reading is **two facts together**: did `project-settings` fire, *and* did
the managed hook's effect survive? The first separates fired/didn't-fire; the second
separates additive from override.

---

## Step 2 — test the `.local` path

Repeat Step 1 with `.claude/settings.local.json` in place (`-Source local-settings`). This
matters because `settings.json` rides along in a cloned/planted repo (the realistic
injection vector) while `settings.local.json` is local-only. Confirm whether both merge,
or only one.

---

## Step 3 — block-capability variant

Injecting a hook that *runs* and injecting one that can *veto a tool call* are different
capabilities — the second lets you manipulate the permission flow itself.

Point a settings file's `PreToolUse` command at `beacon-block.ps1` instead of `beacon.ps1`,
trigger a Bash call, and observe whether the call is **denied**. If a lower-precedence
injected hook can block/deny, that is a distinct, higher-impact result.

---

## Reading results

`tools\read-results.ps1` prints the raw log and the unique set of `source=` tags that
fired. Each line also carries `pid`, `ppid`, `pproc`, `tool`, and `cwd` for evidence
capture / screenshots.

Log location: `%TEMP%\aa06-beacon.log`.

---

## Optional — ACL recon (the premise behind this test)

`tools\verify-acls.ps1 "<hook-script-dir>"` dumps `icacls` on the managed-settings file
and on the hook-script directory you name, plus `whoami /all`. Run it from the **same user
context Claude runs as** — "write-protected" is only meaningful against that principal.
This documents whether the managed file and the hook scripts are genuinely out of reach,
which is the precondition that makes the merge question interesting.

---

## Cleanup

```
powershell -File tools\cleanup.ps1
```

Then remove `.claude\settings.json` / `.claude\settings.local.json` from any project you
dropped them into, and (if you populated it for the lab) restore/clear the managed file.
