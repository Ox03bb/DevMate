package cli

import (
	"fmt"

	cfg "devmate-backend/internal/config"
)

func printBanner() {
	banner := fmt.Sprintf(`%s
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║   ██████╗ ███████╗██╗   ██╗███╗   ██╗ █████╗ ████████╗   ║
║   ██╔══██╗██╔════╝██║   ██║████╗ ████║██╔══██╗╚══██╔══╝  ║
║   ██║  ██║█████╗  ██║   ██║██╔████╔██║███████║   ██║     ║
║   ██║  ██║██╔══╝  ╚██╗ ██╔╝██║╚██╔╝██║██╔══██║   ██║     ║
║   ██████╔╝███████╗ ╚████╔╝ ██║ ╚═╝ ██║██║  ██║   ██║     ║
║   ╚═════╝ ╚══════╝  ╚═══╝  ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝     ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
%s`, cfg.ColorCyan, cfg.ColorReset)
	fmt.Println(banner)
}

func printDeviceInfo(info cfg.ConnectionInfo) {
	fmt.Printf("\n[+] Device Information:\n")
	fmt.Printf("   Host: %s\n", info.Host)
	fmt.Printf("   Port: %d\n", info.Port)
	fmt.Printf("   Name: %s\n\n", info.Name)
}

func printMDNSStarted(ip string, port int) {
	fmt.Printf("\n[+] mDNS service started successfully!\n")
	fmt.Printf("   Service: %s\n", cfg.ServiceName)
	fmt.Printf("   Broadcasting on: %s:%d\n\n", ip, port)
	fmt.Println("Press Ctrl+C to stop...")
}

func printShuttingDown() {
	fmt.Println(cfg.ColorRed + "\n\n[-] Shutting down mDNS service..." + cfg.ColorReset)
}
