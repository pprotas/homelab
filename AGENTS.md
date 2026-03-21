# Project Overview

- Raspberry Pi home server running a Docker Compose stack (`docker-compose.yml`)
- Services are split across purpose-specific bridge networks:
  - `proxy` (`172.20.0.0/24`) -- services exposed through Caddy reverse proxy
  - `dns` (`172.20.1.0/24`) -- DNS stack (AdGuard Home + Unbound)
  - `unifi` (`172.20.2.0/24`) -- UniFi Network Application + MongoDB
  - `kuma` (`172.20.3.0/24`) -- Uptime Kuma + AutoKuma
- Domain: `pawelprotas.com` -- services live at `*.home.pawelprotas.com` (e.g. `adguard.home.pawelprotas.com`)
- Homepage dashboard at `home.pawelprotas.com`

## Services

- **Caddy** (`caddybuilds/caddy-cloudflare`) -- reverse proxy, Let's Encrypt via Cloudflare DNS-01 challenge
- **AdGuard Home** -- DNS ad blocker (port 53), upstream is Unbound
- **Unbound** -- recursive DNS resolver (port 5335, static IP `172.20.1.200` on `dns` network)
- **UniFi Network Application** + **MongoDB** -- network controller, proxied with origin header rewrite for CSRF
- **Tailscale** -- subnet router (`192.168.50.0/24`), enables remote access to all LAN services via Tailscale network
- **Uptime Kuma** + **AutoKuma** -- uptime monitoring with auto-discovery via Docker labels
- **Speedtest Tracker** -- scheduled speed tests, ntfy notifications for threshold breaches (configured via UI)
- **Diun** -- Docker image update notifier, checks for container updates every 6 hours and sends native ntfy notifications to `alerts` topic
- **Glances** -- system monitoring, exports metrics to InfluxDB
- **InfluxDB** -- time-series database storing Glances metrics (Flux query language, bucket `glances`, org `homelab`)
- **Grafana** -- dashboards and alerting, provisioned via YAML files in `grafana/provisioning/`
- **grafana-ntfy** -- sidecar proxy that translates Grafana webhook alerts into clean ntfy notifications (custom-built arm64 image `homelab-grafana-ntfy:latest`)
- **Homepage** -- dashboard
- **OpenCode** -- AI coding agent web UI, mounts `/opt/homelab` as `/workspace`; entrypoint installs `git`, `openssh-client`, `curl`, and the `tea` CLI on every start; configures SSH for Forgejo push access and registers a `tea` login as the `opencode` Forgejo user via API token
- **Forgejo** -- self-hosted Git forge (`forgejo.home.pawelprotas.com`), SQLite backend, SSH on host port 222; push mirror to GitHub (`pprotas/homelab`) via SSH deploy key, syncs on every push; OpenCode interacts via `tea` CLI (issues, PRs) and Forgejo admin CLI via `docker exec` -- load the `forgejo` skill for usage patterns
- **Ntfy** -- self-hosted push notification server (`ntfy.home.pawelprotas.com`), auth enabled (`deny-all` default access), forwards push wake-ups to `ntfy.sh` upstream for iOS/Android instant delivery (message content stays local)
- **iSponsorBlockTV** -- automatically skips sponsor segments, self-promos, interaction reminders, and previews on YouTube TV apps using the SponsorBlock API; also mutes and skips ads; runs with `network_mode: host` for device communication; config in `isponsorblocktv/config.json`
- **Barber Checker** -- polls SalonHub API every 5 min for barber appointment availability, notifies via ntfy topic `barber`; uses Docker Compose `barber` profile so it doesn't start with `docker compose up -d` -- start with `docker compose --profile barber up -d barber-checker`, stop with `docker compose stop barber-checker`

## Key Config Files

- `docker-compose.yml` -- all service definitions
- `caddy/Caddyfile` -- reverse proxy routes and TLS config
- `.env` -- all secrets and credentials (Cloudflare token, MongoDB creds, API keys, etc.)
- `unbound/unbound.conf` -- recursive DNS config
- `unifi/init-mongo.sh` -- MongoDB init script for UniFi
- `homepage/` -- dashboard config (services.yaml, settings.yaml, etc.)
- `grafana/provisioning/` -- Grafana datasources, dashboards, and alerting config (contact points, policies, alert rules)
- `grafana-ntfy/Dockerfile` -- builds the arm64 grafana-ntfy proxy image
- `barber-checker/check.sh` -- barber availability polling script
- `isponsorblocktv/config.json` -- iSponsorBlockTV device pairing and skip category config

## Secrets Management

All secrets are centralized in `.env` and injected via variable substitution:

- **docker-compose.yml** uses `${VAR}` syntax (standard Compose interpolation)
- **unifi/init-mongo.sh** reads `$MONGO_USER` / `$MONGO_PASS` from the container environment
- **homepage/services.yaml** uses `{{HOMEPAGE_VAR_XXX}}` syntax (Homepage's env secret mechanism); the corresponding `HOMEPAGE_VAR_*` env vars are passed to the Homepage container in docker-compose.yml

Never hardcode credentials directly in config files. Add new secrets to `.env` and reference them.

## Git Conventions

This project uses [Conventional Commits](https://www.conventionalcommits.org/).

Format: `<type>(<scope>): <description>`

**Types:**

- `feat` -- new feature or capability
- `fix` -- bug fix
- `refactor` -- code change that neither fixes a bug nor adds a feature
- `docs` -- documentation only
- `chore` -- maintenance tasks (dependency updates, CI, config changes)
- `style` -- formatting, whitespace, etc. (no logic change)

**Scope** is optional but encouraged -- use the service or config name (e.g. `caddy`, `grafana`, `dns`, `docker-compose`).

**Examples:**

```
feat(grafana): add CPU temperature alert rule
fix(caddy): correct upstream for UniFi websocket
chore: update all container images
docs: add barber-checker to README
refactor(dns): simplify Unbound forwarding config
```

Keep the subject line lowercase, imperative mood, no trailing period. Body and footer are optional.

## Running Docker from OpenCode

OpenCode has Docker access via the mounted socket. Before running any `docker compose` commands, **load the `docker` skill** for the required flags and usage patterns.

## DNS Architecture

```
Clients -> AdGuard Home (port 53) -> Unbound (port 5335) -> Root DNS servers
```

Cloudflare DNS has `*.home` and `home` A records pointing to `192.168.50.138` (DNS only).
Unbound has `pawelprotas.com` as a `private-domain` to allow private IP resolution.

## Alerting

All monitoring alerts go to a single ntfy topic `alerts` at `https://ntfy.home.pawelprotas.com`.

- **Uptime Kuma** -- notifications managed declaratively via AutoKuma Docker labels in `docker-compose.yml`
- **Grafana** -- alert rules, contact points, and policies provisioned via YAML in `grafana/provisioning/alerting/`. Alerts route through the grafana-ntfy proxy which converts Grafana webhooks into clean ntfy messages
- **Speedtest Tracker** -- ntfy configured manually via its web UI (no declarative option)
- **Diun** -- container update notifications sent via native ntfy integration (configured via environment variables in `docker-compose.yml`)
