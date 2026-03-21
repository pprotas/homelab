---
name: forgejo
description: Interact with the Forgejo Git forge -- create issues, manage repos, and run admin commands
---

## Overview

The homelab runs a self-hosted Forgejo instance at `https://forgejo.home.pawelprotas.com`. OpenCode can interact with it using two CLIs:

- **tea** -- Gitea/Forgejo client CLI, installed in the OpenCode container at `/usr/local/bin/tea`. Used for day-to-day operations (issues, PRs, repos, labels, milestones, etc.)
- **forgejo** -- server-side admin CLI, available inside the `forgejo` container via `docker exec`. Used for admin operations (user management, token generation, etc.)

## tea CLI

`tea` is pre-configured with a login named `forgejo` authenticated as the `opencode` user.

### Common commands

Always pass `--repo pawel/homelab` (or the appropriate `owner/repo`) since OpenCode's working directory is not a tea-aware git remote.

```sh
# List open issues
tea issues --login forgejo --repo pawel/homelab

# Create an issue (note: use --description, NOT --body)
tea issues create --login forgejo --repo pawel/homelab --title "Issue title" --description "Description"

# View a specific issue
tea issues --login forgejo --repo pawel/homelab 42

# Close an issue
tea issues close --login forgejo --repo pawel/homelab 42

# Add a comment
tea comment --login forgejo --repo pawel/homelab 42 "Comment text"

# List PRs
tea pulls --login forgejo --repo pawel/homelab

# List repos
tea repos --login forgejo

# List labels
tea labels --login forgejo --repo pawel/homelab
```

### tea flags reference

| Flag | Purpose |
|---|---|
| `--login forgejo` | Use the pre-configured Forgejo login |
| `--repo owner/name` | Target repository (required -- no auto-detection) |
| `--output simple` | Plain text output (useful for piping) |
| `--output json` | JSON output |
| `--state open\|closed` | Filter by state |
| `--limit N` | Limit results |

### Token scopes

The `opencode` user's token (`opencode-api-v2`) has these scopes:
- `write:issue` -- create, edit, close issues and comments
- `write:repository` -- repo operations
- `read:user` -- required for tea login

If a command returns 403, the token may need additional scopes. Generate a new one via the Forgejo admin CLI (see below).

## Forgejo admin CLI

For server administration, run commands inside the `forgejo` container as the `git` user:

```sh
docker exec -u git forgejo forgejo admin <command>
```

### Common admin commands

```sh
# List users
docker exec -u git forgejo forgejo admin user list

# Create a user
docker exec -u git forgejo forgejo admin user create --username <name> --password <pass> --email <email>

# Change password
docker exec -u git forgejo forgejo admin user change-password --username <name> --password <newpass>

# Generate an API token
docker exec -u git forgejo forgejo admin user generate-access-token \
  --username <name> \
  --token-name <token-name> \
  --scopes "write:issue,write:repository,read:user" \
  --raw

# List auth sources
docker exec -u git forgejo forgejo admin auth list
```

### Important notes

- Always run as `-u git` -- Forgejo refuses to run as root.
- The Forgejo container is on the `proxy` network, accessible from OpenCode.
- The admin CLI talks directly to the database, no API token needed.
