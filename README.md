# Home Media Server

A self-hosted media server stack built on Docker, managed with Docker Compose. Includes automated media management, a debrid download client, dashboards, and automatic backups to Google Drive.

<p align="center">
  <img src="assets/docker-moby.png" alt="Docker" width="60" height="60">
  <img src="assets/portainer-alt.png" alt="Portainer" width="60" height="60">
  <img src="assets/homepage.png" alt="Homepage" width="60" height="60">
  <img src="assets/jellyfin.png" alt="Jellyfin" width="60" height="60">
  <img src="assets/qbittorrent.png" alt="qBittorrent" width="60" height="60">
  <img src="assets/sonarr.png" alt="Sonarr" width="60" height="60">
  <img src="assets/radarr-light.png" alt="Radarr" width="60" height="60">
  <img src="assets/prowlarr.png" alt="Prowlarr" width="60" height="60">
  <img src="assets/bazarr.png" alt="Bazarr" width="60" height="60">
</p>

---

## Stack Overview

| Service | Purpose | Port |
|---|---|---|
| Socket Proxy | Secure Docker socket access for other containers | internal |
| Portainer | Docker container management UI | 9000 |
| Dozzle | Real-time container log viewer | 8082 |
| Homepage | Main dashboard | 3000 |
| Homarr | Visual dashboard with live service widgets | 7575 |
| Jellyfin | Media server | 8096 |
| qBittorrent | Torrent download client | 8081 |
| Decypharr | TorBox debrid download client (mock qBittorrent API) | 8282 |
| Sonarr | TV show automation | 8989 |
| Radarr | Movie automation | 7878 |
| Prowlarr | Indexer manager for Sonarr/Radarr | 9696 |
| Bazarr | Subtitle downloader | 6767 |
| Watchtower | Automatic container image updates | — |
| Docker GC | Nightly cleanup of unused images | — |
| Rclone Backup | Daily appdata backup to Google Drive | — |
| TorBox Media Center | Generates .strm files from TorBox library for Jellyfin | — |

All media lives at `$DATADIR` (default: `/media/storage`). All app configs live at `~/docker/appdata/`.

---

## Prerequisites

- Fedora/RHEL or Debian/Ubuntu Linux
- Git

```bash
# Fedora
sudo dnf install git

# Ubuntu/Debian
sudo apt install git
```

---

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/1-Archit-1/home_media_server.git ~/home-server
cd ~/home-server
```

### 2. Set a static IP (recommended)

Prevents your server IP from changing on reboot. Find your connection name and gateway first:

```bash
nmcli connection show
ip route show default
```

Then set a static IP:

```bash
nmcli connection modify "YOUR_CONNECTION_NAME" \
  ipv4.method manual \
  ipv4.addresses 192.168.1.200/24 \
  ipv4.gateway 192.168.1.1 \
  ipv4.dns "1.1.1.1,8.8.8.8"

nmcli connection up "YOUR_CONNECTION_NAME"
```

### 3. Configure your settings

The setup script reads defaults from `.env.example` and prompts you for any values not already set. Open it and fill in the top section before running the script:

```bash
nano ~/home-server/.env.example
```

```bash
TZ=America/New_York       # your timezone
SERVER_IP=192.168.1.200   # your static IP from step 2
DATADIR=/media/storage    # where media and downloads are stored
```

The script will prompt you for secrets (TorBox API key, Plex claim token etc.) at runtime — those are never stored in the repo.

### 4. Run the setup script

```bash
cd ~/home-server/scripts
bash udms.sh
```

The script will:
- Install Docker and Docker Compose if not present
- Install Cockpit system management UI
- Create all required directories under `~/docker/`
- Generate `~/docker/.env` from your config
- Copy compose files and seed app configs
- Start all containers

### 5. Access your services

Once the script completes, all services are available at `http://YOUR_SERVER_IP:PORT`:

| Service | URL |
|---|---|
| Homepage | http://SERVER_IP:3000 |
| Homarr | http://SERVER_IP:7575 |
| Portainer | http://SERVER_IP:9000 |
| Dozzle | http://SERVER_IP:8082 |
| Jellyfin | http://SERVER_IP:8096 |
| qBittorrent | http://SERVER_IP:8081 |
| Decypharr | http://SERVER_IP:8282 |
| Sonarr | http://SERVER_IP:8989 |
| Radarr | http://SERVER_IP:7878 |
| Prowlarr | http://SERVER_IP:9696 |
| Bazarr | http://SERVER_IP:6767 |
| Cockpit | http://SERVER_IP:9090 |

---

## Arr Stack Configuration

After the containers are running, configure the services through their web UIs in this order.

### 1. Prowlarr — Add indexers

1. Go to `http://SERVER_IP:9696`
2. **Indexers → Add Indexer** — search and add your preferred indexers (e.g. 1337x, RARBG, etc.)
3. **Settings → Apps → Add Application**:
   - Add Radarr: host `radarr`, port `7878`, API key from Radarr Settings → General
   - Add Sonarr: host `sonarr`, port `8989`, API key from Sonarr Settings → General

### 2. Decypharr — TorBox Setup

1. Go to `http://SERVER_IP:8282` and complete the setup wizard
2. **Add your debrid provider** — select TorBox and enter your API key from [torbox.app](https://torbox.app) → Settings → API
3. **Downloads folder**: `/data/downloads`
4. **Download action** — choose one:
   - **Download (recommended)** — files are fully downloaded to your server. Uses disk space but files are permanent regardless of TorBox retention.
   - **Symlink** — files are not downloaded locally, they point to TorBox's servers via an rclone mount. Zero disk space used but requires rclone mount configuration (see note below), and files expire after TorBox's 30-day retention period.
5. **Mount path** (symlink mode only): `/data/media/torbox` — where Decypharr mounts your TorBox library inside the container.
6. **Add Arr services** — in Decypharr settings, connect Sonarr and Radarr so it notifies them immediately when a download completes:
   - Sonarr: `http://sonarr:8989`, API key from Sonarr → Settings → General
   - Radarr: `http://radarr:7878`, API key from Radarr → Settings → General

> **Symlink + FUSE:** Symlink mode requires the Decypharr filesystem mount to be active so it can access your TorBox cloud library at `/data/media/torbox`. Without it, symlinks will be broken pointers. If you just want things to work simply, use Download mode.

### 3. Download clients — qBittorrent or Decypharr (or both)

You can use either or both download clients simultaneously. Decypharr routes downloads through TorBox debrid, qBittorrent downloads normally via torrents.

**In Radarr and Sonarr — Settings → Download Clients → Add → qBittorrent:**

| Field | qBittorrent | Decypharr |
|---|---|---|
| Name | qBittorrent | Decypharr |
| Host | `qbittorrent` | `decypharr` |
| Port | `8080` | `8282` |
| Category | `radarr` / `sonarr` | `radarr` / `sonarr` |

To use Decypharr by default, set it to higher priority (drag it above qBittorrent in the list). Disable either client at any time to switch between them.

### 3. Radarr — Movies

1. Go to `http://SERVER_IP:7878`
2. **Settings → Media Management → Add Root Folder**: `/data/media/movies`
3. **Settings → Download Clients** — add download client(s) as above
4. Prowlarr sync adds indexers automatically if configured in step 1

### 4. Sonarr — TV Shows

1. Go to `http://SERVER_IP:8989`
2. **Settings → Media Management → Add Root Folder**: `/data/media/tvshows`
3. **Settings → Download Clients** — add download client(s) as above

### 5. Bazarr — Subtitles

1. Go to `http://SERVER_IP:6767`
2. **Settings → Sonarr**: host `sonarr`, port `8989`, API key from Sonarr
3. **Settings → Radarr**: host `radarr`, port `7878`, API key from Radarr
4. **Settings → Providers** — add subtitle providers (OpenSubtitles, Subscene etc.)

### 6. Jellyfin — Media Server

1. Go to `http://SERVER_IP:8096` and complete the initial setup wizard
2. **Add Media Library → Movies**: `/data/media/movies`
3. **Add Media Library → TV Shows**: `/data/media/tvshows`

---

## Google Drive Backup

App configs are automatically backed up daily to Google Drive via the `rclone-backup` container.

### First time setup

Install rclone on the host and authenticate:

```bash
sudo dnf install rclone   # Fedora
# or
sudo apt install rclone   # Ubuntu/Debian

rclone config
```

- Choose `n` for new remote
- Name it `gdrive`
- Select `drive` (Google Drive)
- Leave client ID and secret blank (hit enter)
- Select scope `1` (full access)
- Use auto config: `y` (opens browser for OAuth)
- Shared drive: `n`

Copy the config to the container's config directory:

```bash
mkdir -p ~/docker/appdata/rclone
cp ~/.config/rclone/rclone.conf ~/docker/appdata/rclone/rclone.conf
sudo docker restart rclone-backup
```

Backups run daily at 3am to `homeserver-backup/appdata/` in your Google Drive.

---

## After a System Restart

All containers have `restart: unless-stopped` and Docker is configured to start on boot (handled by the setup script). Everything should come back up automatically — no manual steps needed.

To verify Docker is enabled:

```bash
sudo systemctl is-enabled docker
```

If for some reason it's disabled:

```bash
sudo systemctl enable docker
```

---

## Environment Variables

All environment variables are documented in `.env.example` at the repo root. This file serves as both the template and the reference for what each variable does.

The actual runtime file is `~/docker/.env` — it is never committed to the repo. It is generated by `udms.sh` on first run using `.env.example` as the base, then appending dynamic values (PUID, PGID, homepage URLs etc.) and secrets you enter at the prompts.

**To add a new variable:**
1. Add it (blank or with a safe default) to `.env.example` so it's documented in the repo
2. Add the real value to `~/docker/.env` directly:
```bash
sudo nano ~/docker/.env
```

**Secrets** (API keys, passwords) should only ever exist in `~/docker/.env`, never in `.env.example` or committed files.

---

## TorBox Media Center

TorBox Media Center generates `.strm` files from your TorBox cloud library and organizes them into `movies/` and `series/` folders. Jellyfin can open `.strm` files and stream the content directly from TorBox — no local storage needed.

It runs on a 5-minute schedule and keeps the library in sync with your TorBox account automatically.

### Setup

1. Make sure `TORBOX_API_KEY` is set in `~/docker/.env`
2. Bring up the container:
```bash
dcup
```
3. After a few minutes, `.strm` files will appear at `$DATADIR/media/torbox-strm/`
4. Add the libraries in Jellyfin:
   - **Movies**: `/data/media/torbox-strm/movies`
   - **TV Shows**: `/data/media/torbox-strm/series`

> Files stream directly from TorBox and are subject to TorBox's 30-day retention. If you want a permanent local copy, trigger a download through Sonarr/Radarr/Decypharr.

---

## Making Changes

If you add/remove services in `docker-compose.yml` or modify any config files in `configs/`, re-run the relevant parts manually:

**Copy updated compose files:**
```bash
cp ~/home-server/docker-compose.yml ~/docker/master-compose.yml
cp ~/home-server/compose/<service>.yml ~/docker/compose/<service>.yml
```

**Copy updated app configs (e.g. homepage):**
```bash
cp ~/home-server/configs/homepage/docker-configs/*.yaml ~/docker/appdata/homepage/
```

**Apply changes and bring containers up:**
```bash
dcup
# or force recreate a specific container after a config change:
dcrec <service>
```

**Pull latest images before bringing up:**
```bash
dcpull && dcup
```

---

## Adding More Services

There are 75+ service compose files in the `compose/` directory. To enable one:

1. Add it to `master-compose.yml` under the relevant section:

```yaml
include:
  # UTILITIES
  - compose/filebrowser.yml
```

2. Bring it up:

```bash
sudo docker compose -f ~/docker/master-compose.yml up -d
```

---

## Useful Aliases

After setup, these aliases are available in your shell:

```bash
dcup          # bring up all containers
dcdown        # bring down all containers
dcrec         # force recreate a container: dcrec sonarr
dcrestart     # restart a container: dcrestart jellyfin
dclogs        # tail logs: dclogs radarr
dpss          # show all containers with status
dexec         # exec into container: dexec sonarr bash
dcpull        # pull latest images
dp600         # lock secrets permissions
dp777         # unlock secrets for editing
```

---

## Credits

Original compose files based on [@anandslab](https://github.com/anandslab)'s [docker-traefik](https://github.com/anandslab/docker-traefik) project.
