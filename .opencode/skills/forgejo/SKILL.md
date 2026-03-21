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

### Issue templates

The `tea` CLI does not support issue templates -- it bypasses them entirely. When creating issues via CLI, manually replicate the template structure in the `--description` field. Do NOT use conventional commit format in issue titles (that's for commits only).

**Feature request** -- use this structure:

```
tea issues create --login forgejo --repo pawel/homelab \
  --title "Integrate Foo Service" \
  --description "$(cat <<'EOF'
## Summary

Brief description of the feature or service.

## Tasks

- [ ] Add service to `docker-compose.yml`
- [ ] Configure Caddy reverse proxy route
- [ ] Add secrets/env vars to `.env`
- [ ] Add to Homepage dashboard

## Links

- https://example.com

## Additional Notes

Any extra context, constraints, or considerations.
EOF
)"
```

**Bug report** -- use this structure:

```
tea issues create --login forgejo --repo pawel/homelab \
  --title "Something is broken" \
  --description "$(cat <<'EOF'
## Description

What's broken? What did you expect to happen?

## Steps to Reproduce

1. ...
2. ...

## Relevant Logs

```
paste logs here
```

## Additional Notes

Any extra context.
EOF
)"
```

Omit empty sections rather than leaving them blank.

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

## "Work" Project Board

The `pawel/homelab` repo has a **kanban project board** called "Work" (project ID `1`), accessible in the Forgejo web UI at:

```
https://forgejo.home.pawelprotas.com/pawel/homelab/projects/1
```

### Columns

The board uses the default Forgejo project columns:

| Column | Purpose |
|---|---|
| **Uncategorized** | Newly added issues not yet triaged |
| **To Do** | Triaged and ready to work on |
| **In Progress** | Currently being worked on |
| **Done** | Completed |

### API limitations

Forgejo 14.0.3 has **no REST API for project boards**. You cannot programmatically:
- Add an issue to a project
- Move an issue between columns
- List project columns or cards

The only project-related data available via API is on the **issue timeline** endpoint, which records when an issue is added to a project:

```sh
source /workspace/.env && curl -s \
  "https://forgejo.home.pawelprotas.com/api/v1/repos/pawel/homelab/issues/5/timeline" \
  -H "Authorization: token $FORGEJO_API_TOKEN" | python3 -c "
import json, sys
for e in json.load(sys.stdin):
    if e.get('type') == 'project':
        print(f'project_id={e[\"project_id\"]} old_project_id={e[\"old_project_id\"]}')"
```

### Workflow conventions

Since project board management is web-UI-only, follow these conventions:

1. **Creating issues** -- After creating an issue with `tea`, remind the user to add it to the "Work" project board in the Forgejo web UI. Include the direct URL:
   ```
   Add to project board: https://forgejo.home.pawelprotas.com/pawel/homelab/issues/<number>
   ```

2. **Starting work on an issue** -- When beginning work, remind the user to move the card to "In Progress" on the board.

3. **Completing an issue** -- When closing an issue with `tea issues close`, remind the user to move the card to "Done" (or verify it moved automatically on close, depending on board settings).

4. **All new issues belong on the board** -- Every issue in `pawel/homelab` should be tracked on the "Work" project. Always include the reminder when creating issues.
