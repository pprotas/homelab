---
name: docker
description: Run Docker and Docker Compose commands from inside the OpenCode container, with the correct flags for host volume mounts and secrets
---

## Context

OpenCode runs inside a container with the Docker socket mounted (`/var/run/docker.sock`) and `docker-cli` + `docker-cli-compose` installed at startup. The Docker daemon runs on the **host**, not inside this container. This means relative volume paths in `docker-compose.yml` (e.g. `./barber-checker:/app`) are resolved by the daemon on the host filesystem, not inside this container.

The compose project on the host lives at `/opt/homelab`, which is bind-mounted into this container as `/workspace`.

## Required flags

Every `docker compose` command must include all of these flags:

```sh
docker compose \
  -f /workspace/docker-compose.yml \
  --env-file /workspace/.env \
  -p homelab \
  --project-directory /opt/homelab \
  <command>
```

| Flag | Why |
|---|---|
| `-f /workspace/docker-compose.yml` | Compose file path readable from inside this container |
| `--env-file /workspace/.env` | Secrets file readable from inside this container |
| `-p homelab` | Project name must match the existing stack on the host |
| `--project-directory /opt/homelab` | **Host** path so relative volume mounts resolve correctly on the Docker daemon |

## What breaks without these flags

- **Missing `--project-directory`** -- bind mounts resolve to `/workspace/...` which does not exist on the host, causing "file not found" errors inside target containers.
- **Missing `--env-file`** -- all `${VAR}` references in the compose file default to blank strings, so containers lose credentials and config.
- **Missing `-p homelab`** -- compose creates a new project (e.g. `workspace`) with duplicate networks that conflict with the existing stack's subnet allocations.

## Examples

Restart a service:
```sh
docker compose -f /workspace/docker-compose.yml --env-file /workspace/.env -p homelab --project-directory /opt/homelab up -d caddy
```

Restart a profiled service:
```sh
docker compose -f /workspace/docker-compose.yml --env-file /workspace/.env -p homelab --project-directory /opt/homelab --profile barber up -d barber-checker
```

View logs:
```sh
docker logs <container-name> --tail 50
```

List running containers:
```sh
docker ps --format 'table {{.Names}}\t{{.Status}}'
```

## Notes

- Plain `docker` commands (e.g. `docker logs`, `docker ps`, `docker exec`) work normally without extra flags -- they talk directly to the daemon via the socket.
- Only `docker compose` commands need the flags above because compose resolves paths and variables.
