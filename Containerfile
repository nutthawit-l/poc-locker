FROM docker.io/library/caddy:2.11.3

# I need `dig` for troubleshooting.
RUN apk add bind-tools

