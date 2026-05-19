caddy-image:
	podman build -t caddy:latest .

caddy-file:
	cp templates/caddyfile-cm.yaml caddyfile-cm.yaml
	sed 's/^/    /' Caddyfile >> caddyfile-cm.yaml

server-up:
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
