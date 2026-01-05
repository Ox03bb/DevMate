# DevMate Backend - mDNS Discovery Service

A Go-based mDNS service for DevMate that broadcasts device information and generates QR codes for easy mobile connection.

## Features

- 🔍 mDNS service broadcasting for automatic device discovery
- 📱 QR code generation for manual device connection
- 🖥️ ASCII art QR code display in terminal
- 💾 PNG QR code export

## Prerequisites

- Go 1.21 or higher
- Docker (for testing)

## Installation

```bash
cd backend
go mod download
```

## Usage

Run the mDNS service:

```bash
go run main.go
```

Or build and run:

```bash
go build -o devmate-backend
./devmate-backend
```

## How It Works

1. The service detects your local IP address
2. Starts an mDNS broadcaster on `_devmate._tcp`
3. Generates a QR code containing connection information (host, port, name)
4. Displays the QR code as ASCII art in the terminal
5. Saves the QR code as `devmate-qr.png`

## QR Code Data Format

The QR code contains JSON data:

```json
{
  "host": "192.168.1.100",
  "port": 2375,
  "name": "hostname"
}
```

## Configuration

Default port: `2375` (Docker API port)

To change the port, modify the `servicePort` constant in `main.go`.

## Dependencies

- `github.com/grandcat/zeroconf` - mDNS implementation
- `github.com/skip2/go-qrcode` - QR code generation

## License

Part of the DevMate project.
