# Bazarr

Automated subtitle fetching for the media Sonarr and Radarr manage. Bazarr
reads episode/movie metadata from Sonarr and Radarr, searches subtitle
providers, and writes subtitle files next to the media on the shared
`/mnt/media_pool` volume — the same pool Jellyfin serves from — so Jellyfin
picks up the subtitles automatically with no direct Bazarr↔Jellyfin
integration required.

## Quick start

```bash
mkdir -p ~/development/bazarr/configs   # first time only
just deploy
just forward
```

Open http://localhost:6767 and complete the setup wizard.

## One-time setup (via the Bazarr web UI)

1. **Connect Sonarr** — Settings → Sonarr:
   - Address: `sonarr.sonarr.svc.cluster.local`, Port: `8989`
   - API key: read from `~/development/sonarr/configs/config.xml` (`<ApiKey>` element)
2. **Connect Radarr** — Settings → Radarr:
   - Address: `radarr.radarr.svc.cluster.local`, Port: `7878`
   - API key: read from `~/development/radarr/configs/config.xml`
3. **Path mappings** — none needed. Bazarr, Sonarr, Radarr, and Jellyfin all
   mount the same `/mnt/media_pool` host path at `/data` in-container, so
   paths reported by Sonarr/Radarr resolve directly inside Bazarr.
4. **Subtitle providers/languages** — Settings → Subtitles / Providers, enable
   the providers and languages you want.

## Verifying it works

1. Pick an existing episode or movie already known to Sonarr/Radarr.
2. Trigger a manual subtitle search on it from the Bazarr UI.
3. Confirm the resulting `.srt` file appears next to the media file under
   `/mnt/media_pool` on the host.
4. In Jellyfin, refresh the library (or just open the item) and confirm the
   subtitle track is now listed.

## Recipes

| Command            | Effect                                              |
|---------------------|------------------------------------------------------|
| `just deploy`       | Build, push, and apply manifests                     |
| `just restart`      | Rolling-restart the pod (e.g. after a manual config edit) |
| `just logs`         | Stream pod logs                                       |
| `just forward`      | Port-forward to the pod at `localhost:6767` (background) |
| `just forward-stop` | Stop the port-forward                                 |
| `just teardown`     | Remove all bazarr resources from the cluster           |

## Layout

```
bazarr/
├── Dockerfile     # FROM lscr.io/linuxserver/bazarr:latest
├── configs/       # persisted Bazarr config (bind-mounted as /config)
├── justfile       # deploy/restart/logs/forward/teardown recipes
└── k8s/
    ├── namespace.yaml
    ├── deployment.yaml
    ├── pvc.yaml     # bazarr-config (2Gi) + bazarr-data (3Ti, shared media pool)
    └── service.yaml # ClusterIP, port 6767
```

To include Bazarr in a full cluster redeploy: `cd ~/development/kubernetes && just deploy-apps`.
