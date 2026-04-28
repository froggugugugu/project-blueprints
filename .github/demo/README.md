# Demo recording (maintainers only)

This directory holds the demo GIF used by the project root README and the
VHS tape that produced it. It lives under `.github/` rather than `docs/`
because `docs/` is reserved for end-user (target-project) stub templates.

## Files

- `quickstart.tape` — VHS declarative script (1.3 KB, reproducible)
- `quickstart.gif` — rendered GIF (~715 KB, referenced from root README)

## Re-rendering the GIF

```bash
# 1. Pre-flight: prepare a temp config that disables Claude Code's remote-control
#    URL output (so the GIF doesn't expose a session URL)
echo '{"remoteControlAtStartup": false}' > /tmp/demo-rc-off.json

# 2. Render
vhs .github/demo/quickstart.tape
# → .github/demo/quickstart.gif is regenerated
```

## Required tools

- [vhs](https://github.com/charmbracelet/vhs) — VHS declarative terminal recorder
- [ttyd](https://github.com/tsl0922/ttyd) — vhs runtime dependency (pseudo terminal)
- ffmpeg — vhs runtime dependency (video encoding)

## Why a pre-flight setting file is needed

`vhs` runs **real commands**, so when `claude` launches, it would normally
print its remote-control session URL like
`https://claude.ai/code/session_XXX`. The URL itself is harmless without
authentication, but its presence in a publicly distributed GIF feels
unnecessary. The temp `/tmp/demo-rc-off.json` is copied to the demo
project's `.claude/settings.local.json` in the tape's `Hide` block so
`remoteControlAtStartup: false` takes effect for the recording only.

## Authenticity

`vhs` executes the commands literally, so the GIF is a real Claude Code
session — not a screencast or simulation. To re-render locally you need:

- `git`
- `bash`
- `claude` (Claude Code CLI, authenticated)

If the rendered GIF approaches GitHub's 10 MB README limit, lower
`Set Width` / `Set Height`, raise `Set TypingSpeed`, or trim sleeps.
