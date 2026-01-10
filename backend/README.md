# DevMate Backend

A Go-based backend server for DevMate that provides Docker management, file sharing, and device discovery services.

## Features

- **Docker Proxy** - Routes Docker API requests to the local Docker socket
- **File Server** - Browse, upload, download, and manage files remotely
- **mDNS Discovery** - Automatic service discovery using mDNS/Zeroconf
- **QR Code Connection** - Generate QR codes for easy mobile app pairing

## Requirements

- Go 1.23.0 or later
- Docker (optional, for Docker management features)

## Installation

```bash
cd backend
go mod download
```

## Building

```bash
# Build for current platform
go build -o bin/devmate-backend ./cmd/main.go

```

## Running

```bash
go run ./cmd/main.go
```

Or run the compiled binary:

```bash
./bin/devmate-backend
```

## Architecture

```
backend/
├── cmd/
│   └── main.go           # Application entry point
├── internal/
│   ├── cli/              # CLI interface and startup logic
│   ├── config/           # Configuration and constants
│   ├── fileserver/       # File management HTTP server
│   ├── mDNS/             # mDNS/Zeroconf service discovery
│   ├── proxy/            # Reverse proxy for Docker and file server
│   └── qrcode/           # QR code generation for connection info
├── pkg/
│   └── qrcode/           # Public QR code utilities
├── go.mod
└── go.sum
```

## API Endpoints

The server runs on port **4321** by default.

### Health & Info

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check endpoint |
| `/info` | GET | Server information |

### Docker API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/docker/*` | ANY | Proxied Docker API requests |
| `/docker-sockets` | GET | List available Docker sockets |
| `/docker-sockets/select` | POST | Switch active Docker socket |

### File Server API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/files/list` | GET | List files in a directory |
| `/api/files/download` | GET | Download a file |
| `/api/files/upload` | POST | Upload a file |
| `/api/files/mkdir` | POST | Create a directory |
| `/api/files/delete` | DELETE | Delete a file or directory |
| `/api/files/rename` | POST | Rename a file or directory |
| `/api/files/info` | GET | Get file information |
| `/api/files/search` | GET | Search for files |

## Service Discovery

The backend advertises itself via mDNS with the following service type:

- **Service**: `_devmate._tcp`
- **Domain**: `local.`

This allows the DevMate mobile app to automatically discover the backend on the local network.

## Docker Socket Paths

The backend checks for Docker sockets in the following locations:

1. `/var/run/docker.sock` (Linux/standard)
2. `~/.docker/desktop/docker.sock` (Docker Desktop)
