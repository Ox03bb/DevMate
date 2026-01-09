package cli

import (
	"fmt"
	"log"
	"os"
	"time"

	cfg "devmate-backend/internal/config"
	"devmate-backend/internal/fileserver"
	mdns "devmate-backend/internal/mDNS"
	"devmate-backend/internal/proxy"
	"devmate-backend/internal/qrcode"
)

func Run() {
	printBanner()

	// Get local IP address
	ip, err := getLocalIP()
	if err != nil {
		log.Fatalf("Failed to get local IP: %v", err)
	}

	// Get hostname
	hostname, err := os.Hostname()
	if err != nil {
		log.Fatalf("Failed to get hostname: %v", err)
	}

	// Create connection info
	connInfo := cfg.ConnectionInfo{
		Host: ip,
		Port: cfg.ServicePort,
		Name: hostname,
	}

	printDeviceInfo(connInfo)

	// Generate and display QR code
	if err := qrcode.Display(connInfo); err != nil {
		log.Printf("Warning: Failed to generate QR code: %v", err)
	}

	// Detect available Docker sockets
	dockerSocketPath := cfg.GetDefaultDockerSocket()
	availableSockets := cfg.GetAvailableDockerSockets()

	if dockerSocketPath == "" {
		fmt.Printf("%s⚠ Warning: No Docker socket found!%s\n", cfg.ColorYellow, cfg.ColorReset)
		fmt.Println("  Tried paths:")
		for _, path := range cfg.DockerSocketPaths {
			fmt.Printf("    - %s\n", path)
		}
		fmt.Println("  Docker features will not be available.")
		dockerSocketPath = cfg.DockerSocketPaths[0] // Use default path anyway
	} else {
		fmt.Printf("%s✓ Docker socket: %s%s\n", cfg.ColorGreen, dockerSocketPath, cfg.ColorReset)
		if len(availableSockets) > 1 {
			fmt.Printf("  %d socket(s) available. Use /docker-sockets endpoint to switch.\n", len(availableSockets))
		}
	}

	// Start mDNS server
	server, err := mdns.Start(hostname, ip, cfg.ServicePort)
	if err != nil {
		log.Fatalf("Failed to start mDNS: %v", err)
	}
	defer server.Shutdown()

	printMDNSStarted(ip, cfg.ServicePort)

	// Start file server in background (internal, not exposed directly)
	go func() {
		fileServer := fileserver.NewFileServer("", cfg.FileServerPort)
		log.Printf("Starting internal file server on port %d...\n", cfg.FileServerPort)
		if err := fileServer.Start(); err != nil {
			log.Printf("File server error: %v", err)
		}
	}()

	// Give file server time to start
	time.Sleep(500 * time.Millisecond)

	// Start reverse proxy (main entry point)
	go func() {
		proxyServer := proxy.NewProxyServer(
			cfg.ServicePort,
			dockerSocketPath,
			cfg.FileServerPort,
		)
		log.Printf("Starting reverse proxy on port %d...\n", cfg.ServicePort)
		if err := proxyServer.Start(); err != nil {
			log.Fatalf("Proxy server error: %v", err)
		}
	}()

	// Wait for interrupt signal
	waitForShutdown()

	printShuttingDown()
}
