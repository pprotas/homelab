---
name: ntfy
description: Send push notifications via the self-hosted ntfy server
---

## How it works

OpenCode can send push notifications to phones/desktops via the homelab's ntfy instance. The token is available as `$NTFY_TOKEN` in the container environment. The topic is `opencode`. Both OpenCode and ntfy sit on the `proxy` Docker network, so use the internal URL.

## Sending a notification

**Important:** `curl` is NOT available in the Claude Code container. Use `wget` instead.

```sh
wget -qO- \
  --header="Authorization: Bearer $NTFY_TOKEN" \
  --header="Title: YOUR TITLE" \
  --header="Tags: EMOJI_TAG" \
  --post-data='Your message body' \
  "http://ntfy:80/opencode"
```

### wget flag reference

| wget flag | curl equivalent | Purpose |
|-----------|----------------|---------|
| `--header="Key: Value"` | `-H "Key: Value"` | Set a request header |
| `--post-data='body'` | `-d 'body'` | Send POST data (body) |
| `-qO-` | `-s` | Quiet mode, output to stdout |

### Optional headers

| Header | Example value | Purpose |
|--------|---------------|---------|
| `Title` | `Weather report` | Notification title |
| `Tags` | `warning,thermometer` | Comma-separated emoji shortcodes |
| `Priority` | `min\|low\|default\|high\|urgent` | Delivery urgency |
| `Click` | `https://home.pawelprotas.com` | URL opened on tap |
| `Actions` | `view, Open Dashboard, https://home.pawelprotas.com` | Up to 3 action buttons (semicolon-separated) |
