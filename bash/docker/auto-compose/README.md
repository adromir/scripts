# 🐳 Auto-Compose (Docker to Compose Generator)

[![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25.svg?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Docker](https://img.shields.io/badge/Docker-Compatible-2496ED.svg?logo=docker&logoColor=white)](https://www.docker.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Author](https://img.shields.io/badge/Author-Adromir-informational.svg)](https://github.com/adromir)

**Auto-Compose** is a lightweight, zero-dependency Bash script that automatically inspects all currently running Docker containers and reverse-engineers clean, production-ready `docker-compose.yml` files for each container.

---

## 🌟 Why Use This Tool?

When managing Docker environments—especially on servers where containers were launched manually via `docker run` or third-party web GUIs—maintaining reproducible configuration files is critical. Manually inspecting containers and typing out YAML specifications is tedious and error-prone.

**Auto-Compose** extracts the entire operational state of your running containers directly into standardized Docker Compose files within seconds.

### Key Advantages

* ⚡ **Instant Atomic Generation:** Automatically scans all running containers via `docker ps` and generates individual `<container_name>-compose.yml` files in a single pass.
* 🧹 **Smart Environment Filtering:** Strips transient, container-injected runtime variables (such as `PATH`, `HOSTNAME`, and `HOME`) while preserving your application environment variables.
* 💾 **Precise Volume & Mount Tracking:** Exports all volume bindings and host mounts, accurately preserving read-only (`:ro`) access modes.
* 🌐 **Static Network & IP Preservation:** Captures multi-network attachments and exact static IPv4 addresses, configuring top-level networks as `external: true` to prevent network re-creation conflicts.
* 🔒 **Safe Restart Policies & Custom Commands:** Accurately retains restart rules (`always`, `unless-stopped`, `on-failure`) and explicit entrypoint/command arguments.
* 🪶 **Minimal Dependencies:** Written in pure, portable Bash with `jq` JSON processing—no heavy Python runtime or third-party Docker API wrappers required.

---

## 📸 Output Example

Generated compose files follow the clean Docker Compose v3.8 specification:

```yaml
version: '3.8'
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: always
    ports:
      - "8080:80"
    environment:
      - "SIGNUPS_ALLOWED=false"
      - "WEBSOCKET_ENABLED=true"
    volumes:
      - "/opt/vaultwarden/data:/data:rw"
    networks:
      backend_net:
        ipv4_address: 172.20.0.10

networks:
  backend_net:
    external: true
```

---

## 📋 Prerequisites

Before running the script, ensure you have the following installed on your system:

1. **Bash**: Compatible with Bash 4+.
2. **Docker Engine**: Docker daemon must be running and accessible by the current user (e.g. `docker ps` executes without errors).
3. **jq**: Command-line JSON processor.
   ```bash
   # Debian / Ubuntu
   sudo apt update && sudo apt install jq -y

   # RHEL / CentOS / Fedora
   sudo dnf install jq -y

   # Alpine Linux
   apk add jq
   ```

---

## 🚀 Installation & Usage

### 1. Download / Setup

Navigate to the script directory:

```bash
cd /path/to/scripts/bash/docker/auto-compose
chmod +x auto-compose.sh
```

### 2. Execution

Run the script directly:

```bash
./auto-compose.sh
```

### 3. Output

The script creates an output folder named `docker_compose_files_native/` in the current working directory containing one compose file per active container:

```text
docker_compose_files_native/
├── nginx-proxy-compose.yml
├── postgres_db-compose.yml
└── vaultwarden-compose.yml
```

---

## ⚠️ Disclaimer

This tool is provided for administrative convenience. Always review generated `docker-compose.yml` files before using them in production, especially for sensitive secrets or complex custom network drivers. The author is not liable for misconfigurations or data loss.

---

## 📄 License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

**Author:** Adromir  
**Website:** [https://github.com/adromir](https://github.com/adromir)
