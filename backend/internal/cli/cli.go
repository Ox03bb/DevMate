package cli

import (
	"log"
	"os"

	cfg "devmate-backend/internal/config"
	"devmate-backend/internal/fileserver"
	mdns "devmate-backend/internal/mDNS"
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

	// Start mDNS server
	server, err := mdns.Start(hostname, ip, cfg.ServicePort)
	if err != nil {
		log.Fatalf("Failed to start mDNS: %v", err)
	}
	defer server.Shutdown()

	printMDNSStarted(ip, cfg.ServicePort)

	// Start file server in background
	go func() {
		fileServer := fileserver.NewFileServer("", cfg.FileServerPort)
		log.Printf("Starting file server on port %d...\n", cfg.FileServerPort)
		if err := fileServer.Start(); err != nil {
			log.Printf("File server error: %v", err)
		}
	}()

	// Wait for interrupt signal
	waitForShutdown()

	printShuttingDown()
}
