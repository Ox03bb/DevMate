package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net"
	"os"
	"os/signal"
	"syscall"

	"github.com/grandcat/zeroconf"
	qrcode "github.com/skip2/go-qrcode"
)

const (
	serviceName   = "_devmate._tcp"
	serviceDomain = "local."
	servicePort   = 2375
)

type ConnectionInfo struct {
	Host string `json:"host"`
	Port int    `json:"port"`
	Name string `json:"name"`
}

func main() {
	// Get local IP address
	ip, err := getLocalIP()
	if err != nil {
		log.Fatalf("Failed to get local IP: %v", err)
	}

	// Get hostname
	hostname, err := os.Hostname()
	if err != nil {
		hostname = "DevMate-Server"
	}

	// Create connection info
	connInfo := ConnectionInfo{
		Host: ip,
		Port: servicePort,
		Name: hostname,
	}

	// Print banner
	printBanner()

	fmt.Printf("\n📱 Device Information:\n")
	fmt.Printf("   Host: %s\n", ip)
	fmt.Printf("   Port: %d\n", servicePort)
	fmt.Printf("   Name: %s\n\n", hostname)

	// Generate and display QR code
	if err := displayQRCode(connInfo); err != nil {
		log.Printf("Warning: Failed to generate QR code: %v", err)
	}

	// Start mDNS server
	server, err := startMDNS(hostname, ip, servicePort)
	if err != nil {
		log.Fatalf("Failed to start mDNS: %v", err)
	}
	defer server.Shutdown()

	fmt.Printf("\n✅ mDNS service started successfully!\n")
	fmt.Printf("   Service: %s\n", serviceName)
	fmt.Printf("   Broadcasting on: %s:%d\n\n", ip, servicePort)
	fmt.Println("Press Ctrl+C to stop...")

	// Wait for interrupt signal
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, os.Interrupt, syscall.SIGTERM)
	<-sig

	fmt.Println("\n\n👋 Shutting down mDNS service...")
}

func getLocalIP() (string, error) {
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		return "", err
	}

	for _, addr := range addrs {
		if ipnet, ok := addr.(*net.IPNet); ok && !ipnet.IP.IsLoopback() {
			if ipnet.IP.To4() != nil {
				return ipnet.IP.String(), nil
			}
		}
	}

	return "", fmt.Errorf("no valid IP address found")
}

func startMDNS(hostname, ip string, port int) (*zeroconf.Server, error) {
	// Create mDNS server
	server, err := zeroconf.Register(
		hostname,      // instance name
		serviceName,   // service type
		serviceDomain, // domain
		port,          // port
		[]string{ // TXT records
			fmt.Sprintf("host=%s", ip),
			fmt.Sprintf("version=1.0"),
		},
		nil, // interfaces (nil = all)
	)
	if err != nil {
		return nil, err
	}

	return server, nil
}

func displayQRCode(info ConnectionInfo) error {
	// Convert connection info to JSON
	jsonData, err := json.Marshal(info)
	if err != nil {
		return err
	}

	// Generate QR code
	qr, err := qrcode.New(string(jsonData), qrcode.Medium)
	if err != nil {
		return err
	}

	// Convert to ASCII art
	asciiArt := qr.ToSmallString(false)

	fmt.Println("📲 Scan this QR code to connect:")
	fmt.Println("┌" + string(make([]byte, 60)) + "┐")
	for _, line := range []rune(asciiArt) {
		if line == '\n' {
			fmt.Println()
		} else {
			fmt.Printf("%c", line)
		}
	}
	fmt.Println("└" + string(make([]byte, 60)) + "┘")

	// Also save as image file
	filename := "devmate-qr.png"
	if err := qr.WriteFile(256, filename); err == nil {
		fmt.Printf("\n💾 QR code saved as: %s\n", filename)
	}

	return nil
}

func printBanner() {
	banner := `
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║   ██████╗ ███████╗██╗   ██╗███╗   ███╗ █████╗ ████████╗ ║
║   ██╔══██╗██╔════╝██║   ██║████╗ ████║██╔══██╗╚══██╔══╝ ║
║   ██║  ██║█████╗  ██║   ██║██╔████╔██║███████║   ██║    ║
║   ██║  ██║██╔══╝  ╚██╗ ██╔╝██║╚██╔╝██║██╔══██║   ██║    ║
║   ██████╔╝███████╗ ╚████╔╝ ██║ ╚═╝ ██║██║  ██║   ██║    ║
║   ╚═════╝ ╚══════╝  ╚═══╝  ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝    ║
║                                                          ║
║              mDNS Discovery Service v1.0                 ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
`
	fmt.Println(banner)
}
