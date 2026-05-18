caddy-image:
	podman build -t caddy:latest .

caddy-file:
	cp templates/caddyfile-cm.yaml caddyfile-cm.yaml
	sed 's/^/    /' Caddyfile >> caddyfile-cm.yaml

secret:
	cp templates/secret.yaml secret.yaml
	@printf '\n' >> secret.yaml; \
	value=$$(grep '^CLOUDFLARE_API_TOKEN:' .env | cut -d: -f2- | sed 's/^[[:space:]]*//'); \
	echo "  CLOUDFLARE_API_TOKEN: $$(printf '%s' "$$value" | base64 -w0)" >> secret.yaml

server-up:
	podman kube play secret.yaml
	podman kube play \
		--configmap caddyfile-cm.yaml \
		--configmap vaultwarden-cm.yaml \
		server.yaml

server-down:
	podman kube play --down server.yaml

warden-env:
	cp templates/vaultwarden-cm.yaml vaultwarden-cm.yaml
	sed -i "s|<YOUR_VAULTWARDEN_DOMAIN>|$$(grep '^DOMAIN:' .env | sed 's/^DOMAIN:[[:space:]]*//')|g" vaultwarden-cm.yaml
	sed -i "s|<YOUR_VAULTWARDEN_ROCKET_PORT>|$$(grep '^ROCKET_PORT:' .env | sed 's/^ROCKET_PORT:[[:space:]]*//')|g" vaultwarden-cm.yaml