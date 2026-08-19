# Install paste (homepage / README / in-app)

Short prompt a first-time user pastes into their coding agent. One copy for every hero host. The agent fills `--app`,
installs the plugin, follows that host’s load step, then runs `kestral-setup`.

Marketing, plugin README, and in-app setup should copy the fenced block verbatim.

```
Install the Kestral plugin in this app, then connect and start a first plan.

curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app <this-host> --with-hooks

Fill --app with the host you are running in: cursor, claude-code, or codex.

After install, load the plugin, then run kestral-setup:
- Cursor: skills are in this session. If Kestral needs authentication, open Settings → Tools & MCPs and click Connect. Then run kestral-setup.
- Claude Code: First detect whether you're running in Desktop or CLI. Check your shell's process ancestry using whatever method is native to your OS, walking up a bounded number of levels and stopping immediately on an empty, missing, or repeated parent PID. If any ancestor is a Claude.app (or equivalent packaged desktop app) process, output exactly desktop; otherwise output exactly cli. cli: /reload-plugins, then /kestral:kestral-setup. desktop: fully quit and reopen so the plugin appears. Go to Customize → Plugins → Kestral → Connectors and click Install for the Kestral MCP connector, then fully quit and reopen again. Start a new chat and run /kestral:kestral-setup (open chats keep their old plugin and tool snapshot).
- Codex: fully quit and reopen. Authenticate (CLI: `codex mcp login Kestral`; app: Plugins → Kestral → MCP servers gear), then start a new thread using /new and run $kestral-setup.

kestral-setup walks Authorize, asks what you want to plan, and puts a multi-phase plan in Kestral.
```
