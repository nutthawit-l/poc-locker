FROM docker.io/library/caddy:2.11.3-builder AS builder

RUN xcaddy build --with github.com/caddy-dns/cloudflare

FROM docker.io/library/caddy:2.11.3

# I need `dig` for troubleshooting.
RUN apk add bind-tools

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
