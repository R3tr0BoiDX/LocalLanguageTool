# LocalLanguageTool

A self-hosted, private [LanguageTool](https://languagetool.org) server: an offline
alternative to Grammarly. Built for a Raspberry Pi 5 (arm64) running Docker, but it
works on any amd64/arm64 Docker host.

It uses the [`erikvl87/languagetool`](https://github.com/Erikvl87/docker-languagetool)
image and optionally the n-gram data sets, which improve detection of commonly confused
words (*their/there*, *das/dass*).

## Requirements

- Docker with the Compose plugin (`docker compose`)
- `curl`, and `unzip` or `python3`, for downloading n-grams
- RAM: the defaults (2 GB Java heap, 3 GB container cap) target an 8 GB Pi 5
- Disk: German and English n-grams together need a lot of space (the English set alone is
  well over 8 GB). During extraction, the archive and the extracted data exist side by side;
  the script checks free space first.

> **SD card vs. SSD:** n-grams are large Lucene indexes that get lots of random reads.
> They work from an SD card but are slow and add wear. An NVMe/USB SSD is strongly
> recommended (see [Moving n-grams to an SSD](#moving-n-grams-to-an-ssd)).

## Setup

```bash
git clone https://github.com/R3tr0BoiDX/LocalLanguageTool.git
cd LocalLanguageTool
cp .env.example .env      # adjust if needed
./download.sh             # German + English n-grams; or e.g. ./download.sh en
docker compose up -d
```

**Download the n-grams before the first start.** If `languageModel` is set but the folder
for a language is missing (e.g. `ngrams/de`), LanguageTool silently disables spell checking
for that language. Check the logs for such warnings:

```bash
docker compose logs | grep "ngram index dir"
```

The first start can take a minute or two; `docker compose ps` shows `healthy` once ready.
Quick test:

```bash
curl --data "language=en-US&text=Their is a problem." http://localhost:8010/v2/check
```

## Configuration (`.env`)

| Variable       | Default    | Meaning                                                          |
|----------------|------------|------------------------------------------------------------------|
| `LT_BIND`      | `0.0.0.0`  | Address the port is published on (`127.0.0.1` = host only)       |
| `LT_PORT`      | `8010`     | Port on the host                                                 |
| `NGRAMS_DIR`   | `./ngrams` | Host folder containing `de/`, `en/`, … (also used by `download.sh`) |
| `JAVA_XMS`     | `512m`     | Initial Java heap                                                |
| `JAVA_XMX`     | `2g`       | Maximum Java heap                                                |
| `LT_MEM_LIMIT` | `3g`       | Hard memory cap for the container                                |

Further [LanguageTool server options](https://languagetool.org/development/api/org/languagetool/server/HTTPServerConfig.html)
can be added to `compose.yml` under `environment:` as `langtool_<option>`.

### Moving n-grams to an SSD

```bash
docker compose down
sudo mkdir -p /mnt/nvme/ngrams
sudo rsync -a ngrams/ /mnt/nvme/ngrams/
# in .env:
#   NGRAMS_DIR=/mnt/nvme/ngrams
docker compose up -d
```

## Security

With `LT_BIND=0.0.0.0`, the server is reachable **by every device in your LAN without
authentication** over plain HTTP, and it allows requests from any origin (needed by the
browser extensions). Don't forward the port to the internet. To restrict it, set `LT_BIND`
to `127.0.0.1` or a specific interface IP, or put it behind a reverse proxy with HTTPS
and/or authentication.

## Browser extension

- [Chrome Web Store](https://chromewebstore.google.com/detail/grammar-checker-paraphras/oldceeleldhonbafppcapldpdifcinji)
- [Firefox Add-ons](https://addons.mozilla.org/en-US/firefox/addon/languagetool/)

In the extension settings, open *Advanced settings*, choose *Other server*, and enter:

```
http://<pi-ip>:8010/v2
```

To get American English and German as used in Germany, set the language variants in the
extension settings to **English (US)** and **German (Germany)**. The n-gram data is per
language (`en`, `de`) and covers all variants.

![Extension settings](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/m4rouvvqex4eq0fsqfmq.png)

If the Firefox extension refuses to connect to the local server, see the image's
[CORS workaround](https://github.com/Erikvl87/docker-languagetool/tree/master/cors-workaround).

## Updating

`compose.yml` uses the `latest` tag, so pulling a new image can move to a new LanguageTool
version:

```bash
docker compose pull
docker compose up -d
```

To pin a version instead, replace `latest` with a tag such as `6.8`
([available tags](https://hub.docker.com/r/erikvl87/languagetool/tags)).
