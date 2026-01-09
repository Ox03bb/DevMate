package config

import (
	"net"
	"os"
	"path/filepath"
	"time"
)

const (
	ServiceName   = "_devmate._tcp"
	ServiceDomain = "local."
	ServicePort   = 4321 // Main proxy port exposed to Flutter app

	FileServerPort = 8888 // Internal file server port (not exposed)
)

// Docker socket paths to try in order of preference
var DockerSocketPaths = []string{
	"/var/run/docker.sock",
	filepath.Join(os.Getenv("HOME"), ".docker/desktop/docker.sock"),
}

// GetAvailableDockerSockets returns a list of Docker sockets that are accessible
func GetAvailableDockerSockets() []string {
	var available []string
	for _, path := range DockerSocketPaths {
		if isSocketAvailable(path) {
			available = append(available, path)
		}
	}
	return available
}

// GetDefaultDockerSocket returns the first available Docker socket path
// Returns empty string if no socket is available
func GetDefaultDockerSocket() string {
	for _, path := range DockerSocketPaths {
		if isSocketAvailable(path) {
			return path
		}
	}
	return ""
}

// isSocketAvailable checks if a Unix socket exists and is connectable
func isSocketAvailable(path string) bool {
	// First check if file exists
	info, err := os.Stat(path)
	if err != nil {
		return false
	}

	// Check if it's a socket
	if info.Mode()&os.ModeSocket == 0 {
		return false
	}

	// Try to connect to verify it's working
	conn, err := net.DialTimeout("unix", path, 2*time.Second)
	if err != nil {
		return false
	}
	conn.Close()
	return true
}

const (
	ColorReset  = "\033[0m"
	ColorRed    = "\033[31m"
	ColorGreen  = "\033[32m"
	ColorYellow = "\033[33m"
	ColorBlue   = "\033[34m"
	ColorPurple = "\033[35m"
	ColorCyan   = "\033[36m"
	ColorWhite  = "\033[37m"
)
