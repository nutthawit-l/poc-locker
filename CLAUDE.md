# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A self-hosted personal "locker" running on a Hetzner cloud server, accessible **only through a Netbird VPN tunnel**. No ports are exposed to the public internet. All traffic is gated by firewall rules that allow only the Netbird subnet (`100.115.0.0/16`).

Services in the pod:
- **Caddy** — reverse proxy with internal TLS (self-signed CA)
- **Vaultwarden** — Bitwarden-compatible password manager (port 8081, localhost-only on host)
- **Filebrowser** — web file manager (port 8082)
- **dufs** — simple file server (port 5000, not exposed to host)

## Architecture

Netbird runs **on the host**, not inside a container. This is intentional: running it in a container would create the `wt0` interface inside the container's network namespace, making the VPN route invisible to the host kernel.

The four services run as a single **Podman pod** managed via Kubernetes YAML (`server.yaml`). The pod is deployed with `podman kube play`, which accepts ConfigMaps as separate files. Caddy uses `tls internal` (its own CA) rather than ACME/Let's Encrypt, so the CA cert (`caddy-root.crt`) must be distributed to each client machine and browser.

Config flow:
1. `templates/` holds example/skeleton files — copy and edit before use.
2. `Caddyfile` is the live config; it gets embedded into `caddyfile-cm.yaml` by `make caddy-file`.
3. `.env` holds `DOMAIN:` and `ROCKET_PORT:` values; `make warden-env` substitutes them into `vaultwarden-cm.yaml`.
4. `server.yaml` is derived from `templates/server.yaml` (pod name is patched with `yq`).

## Key Make Commands

```bash
make caddy-image   # Build the custom Caddy image (adds `dig` via apk)
make caddy-file    # Embed Caddyfile into caddyfile-cm.yaml ConfigMap
make warden-env    # Generate vaultwarden-cm.yaml from .env values
make server-up     # Deploy/update the pod: podman kube play with both ConfigMaps
make server-down   # Tear down the pod
```

## Updating the Caddyfile

After editing `Caddyfile`, run all three steps:

```bash
make caddy-file
podman kube play --replace server.yaml --configmap caddyfile-cm.yaml --configmap vaultwarden-cm.yaml
podman pod restart locker
```

## Running Inside Distrobox

If working from inside a distrobox container, prefix `podman` and `make` calls with `distrobox-host-exec` so they run against the host Podman daemon:

```bash
distrobox-host-exec make server-up
distrobox-host-exec podman pod restart locker
```

## Sysctl Requirement

Caddy binds ports 80 and 443 on the host as an unprivileged user. This requires:

```bash
echo 'net.ipv4.ip_unprivileged_port_start=80' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

## Debugging Containers

When Caddy fails to start (e.g., bad env), `podman exec` is unavailable. Inspect env directly:

```bash
podman inspect <CONTAINER_NAME> --format '{{range .Config.Env}}{{println .}}{{end}}'
podman logs locker-caddy 2>&1 | tail -20
```

To remove a Podman secret:

```bash
podman secret rm <SECRET_NAME>
```
