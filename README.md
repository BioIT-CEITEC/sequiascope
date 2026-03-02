# sequiaScope

**sequiaScope** is a Shiny-based web application for interactive visualization and annotation of next-generation sequencing results — somatic and germline variant calling, fusion genes, expression profiles, and network graphs.

---

## Quick Start — Docker Hub (recommended)

No build required. Pre-built images are available on Docker Hub:

| Image | Docker Hub |
|---|---|
| App | [`juraskovakaterina/sequiascope-app`](https://hub.docker.com/r/juraskovakaterina/sequiascope-app) |
| IGV | [`juraskovakaterina/sequiascope-igv`](https://hub.docker.com/r/juraskovakaterina/sequiascope-igv) |

### Prerequisites

- **Linux** (required — IGV snapshot generation uses Xvfb)
- [Docker](https://docs.docker.com/engine/install/) ≥ 24
- [Docker Compose](https://docs.docker.com/compose/install/) plugin (`docker compose`) or standalone (`docker-compose`)

Verify:

```bash
docker --version
docker compose version
```

---

### 1. Prepare your working directory

Create the required folder structure. Your input data goes into `input_files/`, the app writes session and output data to `output_files/`.

```
my-sequiascope/
├── docker-compose.hub.yml   ← download from this repo (see below)
├── input_files/             ← put your data here
└── output_files/            ← created automatically on first run
```

Create the directories:

```bash
mkdir -p my-sequiascope/input_files my-sequiascope/output_files
cd my-sequiascope
```

### 2. Download the compose file

```bash
curl -O https://raw.githubusercontent.com/katjur01/sequiaScope/main/docker-compose.hub.yml
```

Or download it manually from this repository and place it in your working directory.

### 3. Pull the images

```bash
docker compose -f docker-compose.hub.yml pull
```

### 4. Start the application

```bash
docker compose -f docker-compose.hub.yml up -d
```

### 5. Open in browser

```
http://localhost:8080
```

The application may take 10–20 seconds to start on first launch.

### 6. Stop the application

```bash
docker compose -f docker-compose.hub.yml down
```

---

## Input data structure

Place your patient data inside `input_files/`. The app auto-detects files based on their names and directory structure. See the [Data requirements](docs/data-requirements.html) documentation for the full specification.

Typical structure:

```
input_files/
├── somatic/
│   └── PATIENT_ID/
│       └── PATIENT_ID_somatic.tsv
├── germline/
│   └── PATIENT_ID/
│       └── PATIENT_ID_germline.tsv
├── fusion/
│   └── PATIENT_ID/
│       ├── PATIENT_ID_fusion.tsv
│       └── PATIENT_ID.bam
├── expression/
│   └── PATIENT_ID/
│       └── PATIENT_ID_spleen.tsv
└── reference/
    ├── kegg_pathways.tsv
    └── genes_of_interest.tsv
```

---

## IGV snapshots

The `sequiascope-igv` container automatically generates IGV screenshots for fusion gene visualizations when BAM files are provided. It watches the `output_files/sessions/` directory and processes batch files written by the app.

> **Note for Kubernetes / environments without Docker Compose:**
> If the IGV container is not running, the application will still work — fusion tables load without screenshots. The app detects the missing IGV watcher and skips snapshot generation gracefully.

---

## Configuration

The app reads a `config.yml` file from the working directory. When running with Docker, the config is embedded in the image. If you need to customize file patterns, tissue names, or reference paths, you can mount your own config:

```yaml
# docker-compose.hub.yml — add to the 'app' service:
    volumes:
      - ./input_files:/input_files:ro
      - ./output_files:/output_files
      - ./config.yml:/home/shiny/app/config.yml:ro   # custom config
```

---

## Build from source

If you want to build the images yourself instead of pulling from Docker Hub:

```bash
git clone https://github.com/katjur01/seqUIaSCOPE.git
cd seqUIaSCOPE
docker compose build
docker compose up -d
```

---

## Documentation

Full documentation is available in the [`docs/`](docs/index.html) folder or online. Topics include:

- [Data requirements](docs/data-requirements.html)
- [Upload data](docs/upload-data.html)
- [Variant calling](docs/variant-calling.html)
- [Fusion genes](docs/fusion-genes-1.html)
- [Expression profile](docs/expression-profile-1.html)
- [Network graph](docs/network-graph.html)

---

## Troubleshooting

**Application doesn't start**

```bash
docker compose -f docker-compose.hub.yml logs app
```

**No data visible after upload**

- Check that file names match the expected patterns (see Data requirements)
- Verify that `input_files/` is mounted correctly: `docker exec sequiascope-app ls /input_files`

**IGV snapshots not generated**

- Confirm the IGV container is running: `docker ps | grep igv`
- Check IGV logs: `docker compose -f docker-compose.hub.yml logs igv`
- Fusion tables will load without screenshots if IGV is unavailable

**Port conflict**

If port 8080 is already in use, change the mapping in `docker-compose.hub.yml`:

```yaml
ports:
  - "8888:8080"   # use port 8888 instead
```