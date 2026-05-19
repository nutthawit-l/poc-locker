# Create Personal Locker that only you can access on Hetzner

Tech stack included: Netbird, Caddy, Vaultwarden, Filebrowser

## TODO

Use Netbird DNS instead of Cloudflare

## Architecture


## Pre-requerist

- Podman: 
- Domain that registered on Cloudflare:
- Netbird account: For create SETUP_KEY token

## Setup the Server on Hetzner

### Create the Server on Hetzner

1. Prepare cloudinit file

```console
$ cp templates/leap16-cloudinit-example.yaml cloudinit.yaml
```

Change `<YOUR_USER>` to username you will be create on the server.

Change `<YOUR_SSH_PUB_KEY>` copy you `id_rsa.pub` and paste here.

2. Create VM on Hetzner

### Setup private connect with Netbird

1. Install Netbird

We will install *netbird* on host. we not runs inside a container, because it creates the `wt0` interface and routing rules inside the container's network namespace, not the host's. So the host kernel never sees the route.

```console
server$ sudo zypper addrepo https://pkgs.netbird.io/yum/ netbird
server$ sudo zypper in netbird
```

[openSUSE netbird install - official site](https://docs.netbird.io/get-started/install/linux#open-suse-zypper)

2. Start service

```console
server$ sudo systemctl enable --now netbird
server$ sudo netbird up --setup-key <SETUP_KEY_FOR_SERVER>
Connected
```

[Register machine using setup keys - official site](https://docs.netbird.io/manage/peers/register-machines-using-setup-keys#related-video-content)

3. Verify service is started

```console
server$ ip addr show wt0
3: wt0: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1280 qdisc noqueue state UNKNOWN group default qlen 1000
    link/none 
    inet <ADDR>/16 brd <NETMASK> scope global wt0
       valid_lft forever preferred_lft forever

server$ ip route show dev wt0
<ADDR>/16 proto kernel scope link src <ADDR>
```

4. Go to Netbird [Peers Dashboard](https://app.netbird.io/peers), if the server is runs successfully the peer is created automatically.

![Verify Netbird Peer is created automatically after Netbird server is runs successfully](/home/tie/Pictures/Screenshots/poc-locker/verify-netbird-peer-auto-create-after-netbird-running-successfully.png)

5. Allow traffic from Netbird

```console
server$ sudo firewall-cmd --list-all
public (default, active)
  target: default
  ingress-priority: 0
  egress-priority: 0
  icmp-block-inversion: no
  interfaces: eth0
  sources: 
  services: dhcpv6-client ssh
  ports: 
  protocols: 
  forward: yes
  masquerade: no
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 

server$ sudo firewall-cmd --set-default-zone=drop
success

server$ ZONE=myhome

server$ sudo firewall-cmd --permanent --new-zone="${ZONE}"
success

server$ sudo firewall-cmd --permanent --zone="${ZONE}" --add-port=51820/udp
success

server$ sudo firewall-cmd --reload
success

server$ sudo firewall-cmd --zone="${ZONE}" --list-all
myhome
  target: default
  ingress-priority: 0
  egress-priority: 0
  icmp-block-inversion: no
  interfaces: 
  sources: 
  services: 
  ports: 51820/udp
  protocols: 
  forward: no
  masquerade: no
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 
```

## Test with SSH access from client

We will set firewall to allow SSH from only Netbird Peer.

1. First you need to install and start netbird service on client machine look at step 1 and 2 on: [Setup Netbird](#Setup Netbird)

2. Allow firewall rule on the Server

```console
$ sudo firewall-cmd --permanent --zone="${ZONE}" --add-rich-rule='rule family="ipv4" source address="100.115.0.0/16" port port="22" protocol="tcp" accept'
success

$ sudo firewall-cmd --reload
success
```

3. Test SSH via Server peer address

```console
$ ssh <USER>@<SERVER_PEER_ADDR>
```

### Deploy the Locker service

1. Clone this repository on the server

```console
server$ git clone https://github.com/nutthawit-l/poc-locker.git locker
```

2. Copy *.env.example* to *.env* and replace all placeholder

3. Copy Caddyfile in templates directory `cp templates/Caddyfile Caddyfile` and replace `<SUB1.DOMAIN.COM>` and `<SUB2.DOMAIN.COM>` with you cloudflare registered domain (e.g., `vault.example.com` and `file.example.com`)

> **[Reference]**
>  - https://caddyserver.com/docs/caddyfile/directives/reverse_proxy
>  - https://caddyserver.com/docs/caddyfile/directives/header

4. Create Caddy image that include `github.com/caddy-dns/cloudflare` plugin, this used for auto renew certificate.

```console
server$ make caddy-image
```

5. Convert the *Caddyfile* to ConfigMap (This step run once when we make changed to the *Caddyfile*)

```console
server$ make caddy-file
```

6. Create ConfigMap for *Vaultwarden* env

```console
server$ make warden-env
```

7. Create Secret for *CLOUDFLARE_API_TOKEN*

```console
server$ make secret
```

8. Run the service with Podman

```console
server$ cp templates/server.yaml server.yaml
server$ yq e -i '(select(.kind == "Pod") | .metadata.name) = "locker"' server.yaml
server$ echo 'net.ipv4.ip_unprivileged_port_start=80' | sudo tee -a /etc/sysctl.conf
server$ sudo sysctl -p
server$ make server-up
```

9. Verify the Caddy can obtained certificate by look at Caddy log and search for `"msg":"certificate obtained successfully","identifier":"<SUB.DOMAIN.COM>",`

```console
podman logs -f locker-caddy
```

### Access the service

1. Now you need to point the DNS on Cloudflare to the *Server peer address*

![Point DNS to Server peer address]()


2. Allow 80/443 and ICMP only from NetBird subnet

```console
server$ ZONE=myhome

server$ sudo firewall-cmd --permanent --zone="${ZONE}" --add-rich-rule='rule family="ipv4" source address="100.115.0.0/16" port port="80" protocol="tcp" accept'
success

server$ sudo firewall-cmd --permanent --zone="${ZONE}" --add-rich-rule='rule family="ipv4" source address="100.115.0.0/16" port port="443" protocol="tcp" accept'
success

server$ sudo firewall-cmd --permanent --zone="${ZONE}" --add-icmp-block-inversion
success

server$ sudo firewall-cmd --permanent --zone="${ZONE}" --remove-icmp-block=echo-request
Warning: NOT_ENABLED: echo-request
success

server$ sudo firewall-cmd --reload
success

server$ sudo firewall-cmd --zone="${ZONE}" --list-all
myhome
  target: default
  ingress-priority: 0
  egress-priority: 0
  icmp-block-inversion: no
  interfaces: 
  sources: 
  services: 
  ports: 51820/udp
  protocols: 
  forward: no
  masquerade: no
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 
```

3. Test access the service 

```console
$ domain=<SUB.DOMAIN.COM>
$ dig $domain +short
$ nc -zv $domain 80
$ nc -zv $domain 443
$ nc -zv $domain 22
```

## Appendix

### Get Netbird SETUP_KEY

## Troubleshooting

### Failed to start pod

```console
starting container 28e70f7ceaef0e557b7ca03a38c4354b4c9a4ed3d10aee8b019abc6b7ab19ee1: rootlessport cannot expose privileged port 80, you can add 'net.ipv4.ip_unprivileged_port_start=80' to /etc/sysctl.conf (currently 1024), or choose a larger port number (>= 1024): listen tcp 0.0.0.0:80: bind: permission denied
```

This error happend because *Caddy* try to bind 80 and 443 ports to host but you have not yet allow to "**unprivileged** binding port start from 80"

**Temporary Fix (immediate, resets on reboot)**

```console
$ sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80
$ sudo sysctl net.ipv4.ip_unprivileged_port_start
net.ipv4.ip_unprivileged_port_start = 80
```

**Persistent Fix (survives reboots)**

Add the setting to `/etc/sysctl.conf`:

```console
$ echo 'net.ipv4.ip_unprivileged_port_start=80' | sudo tee -a /etc/sysctl.conf
$ sudo sysctl -p
```

### API token '' appears invalid

```console
$ podman logs -f poc-locker-caddy
Error: loading initial config: loading new config: loading http app module: provision http: getting tls app: loading tls app module: provision tls: provisioning automation policy 0: loading TLS automation management module: position 0: loading module 'acme': provision tls.issuance.acme: loading DNS provider module: loading module 'cloudflare': provision dns.providers.cloudflare: API token '' appears invalid; ensure it's correctly entered and not wrapped in braces nor quotes
```

In this state Caddy isn't start propery, thus you can't shell to it's with `podman exec`, so if you want to check env inside container you must use:

```console
$ podman inspect poc-locker-caddy --format '{{.Config.Env}}'
```

### If you facing a Secret problem and want to delete use:

```console
distrobox-host-exec podman secret rm <YOUR_SECRET_NAME>
```

### Show container `env`

```console
distrobox-host-exec podman inspect <CONTAINER_NAME> --format '{{range .Config.Env}}{{println .}}{{end}}'
```

### Re-generate Netbird `SETUP_KEY` for the client

After add new key to `NB_SETUP_KEY_CLIENT` in *.env* file, run these command:

```console
distrobox-host-exec podman secret rm client-secret
make client-secret
distrobox-host-exec make client-down
distrobox-host-exec make client-up
```

### Remove any previously set sources from the zone 

```console
$ sudo firewall-cmd --permanent --zone="${ZONE}" --list-rich-rules

$ sudo firewall-cmd --permanent --zone="${ZONE}" --remove-rich-rule='<ONE_LINE_ABOVE_OUTPUT>'
```

### Run `podman` cli inside `distrobox` use:

```console
distrobox-host-exec make server-up
```

### Replace Caddyfile

What should I do after update Caddyfile.

1. Generate new ConfigMap

```console
make caddy-file
```

2. Replace the old one

```console
podman kube play --replace server.yaml --configmap caddyfile-cm.yaml --configmap vaultwarden-cm.yaml
```

3. Restart pod

```console
podman pod restart locker
```

4. Log the caddy and looking for *enabling automatic TLS*

```console
podman logs locker-caddy 2>&1 | tail -20
{"level":"info","ts":1779150741.733714,"logger":"http","msg":"enabling automatic TLS certificate management","domains":["<SUB.DOMAIN.COM>","<SUB.DOMAIN.COM>","localhost"]}
```
