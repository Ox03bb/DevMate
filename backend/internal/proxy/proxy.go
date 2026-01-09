package proxy

import (
	"context"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httputil"
	"strings"
	"sync"
	"time"

	"devmate-backend/internal/config"

	"github.com/gin-gonic/gin"
)

// ProxyServer is a reverse proxy that routes requests to different backends
type ProxyServer struct {
	port             int
	dockerSocketPath string
	fileServerPort   int
	router           *gin.Engine
	mu               sync.RWMutex
}

// NewProxyServer creates a new reverse proxy server
func NewProxyServer(port int, dockerSocketPath string, fileServerPort int) *ProxyServer {
	return &ProxyServer{
		port:             port,
		dockerSocketPath: dockerSocketPath,
		fileServerPort:   fileServerPort,
	}
}

// Start starts the reverse proxy server
func (p *ProxyServer) Start() error {
	gin.SetMode(gin.ReleaseMode)
	p.router = gin.New()
	p.router.Use(gin.Recovery())
	p.router.Use(p.corsMiddleware())

	// Route /docker/* to Docker socket
	p.router.Any("/docker/*path", p.handleDocker)

	// Route /api/files/* to file server
	p.router.Any("/api/files/*path", p.handleFileServer)

	// Health check endpoint
	p.router.GET("/health", p.handleHealth)

	// Info endpoint
	p.router.GET("/info", p.handleInfo)

	// Docker socket management endpoints
	p.router.GET("/docker-sockets", p.handleListDockerSockets)
	p.router.POST("/docker-sockets/select", p.handleSelectDockerSocket)

	addr := fmt.Sprintf(":%d", p.port)
	fmt.Printf("Reverse proxy starting on port %d\n", p.port)
	fmt.Printf("  /docker/*     -> Docker socket (%s)\n", p.dockerSocketPath)
	fmt.Printf("  /api/files/*  -> File server (port %d)\n", p.fileServerPort)

	return p.router.Run(addr)
}

// GetDockerSocketPath returns the current Docker socket path (thread-safe)
func (p *ProxyServer) GetDockerSocketPath() string {
	p.mu.RLock()
	defer p.mu.RUnlock()
	return p.dockerSocketPath
}

// SetDockerSocketPath sets the Docker socket path (thread-safe)
func (p *ProxyServer) SetDockerSocketPath(path string) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.dockerSocketPath = path
}

// corsMiddleware adds CORS headers to responses
func (p *ProxyServer) corsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS, HEAD")
		c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Registry-Auth")
		c.Header("Access-Control-Expose-Headers", "Content-Disposition, Content-Length, Docker-Content-Digest")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusOK)
			return
		}

		c.Next()
	}
}

// handleDocker proxies requests to the Docker socket
func (p *ProxyServer) handleDocker(c *gin.Context) {
	// Get the path after /docker
	path := c.Param("path")
	if path == "" {
		path = "/"
	}

	// Get current socket path (thread-safe)
	socketPath := p.GetDockerSocketPath()

	// Create a custom transport that uses Unix socket
	transport := &http.Transport{
		DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
			return net.DialTimeout("unix", socketPath, 10*time.Second)
		},
		DisableCompression: true,
	}

	// Create reverse proxy
	proxy := &httputil.ReverseProxy{
		Director: func(req *http.Request) {
			req.URL.Scheme = "http"
			req.URL.Host = "localhost"
			req.URL.Path = path
			req.URL.RawQuery = c.Request.URL.RawQuery
			req.Host = "localhost"

			// Copy headers
			for key, values := range c.Request.Header {
				for _, value := range values {
					req.Header.Set(key, value)
				}
			}
		},
		Transport: transport,
		ModifyResponse: func(resp *http.Response) error {
			// Add CORS headers to response
			resp.Header.Set("Access-Control-Allow-Origin", "*")
			return nil
		},
		ErrorHandler: func(w http.ResponseWriter, r *http.Request, err error) {
			http.Error(w, fmt.Sprintf("Docker proxy error: %v", err), http.StatusBadGateway)
		},
	}

	proxy.ServeHTTP(c.Writer, c.Request)
}

// handleFileServer proxies requests to the file server
func (p *ProxyServer) handleFileServer(c *gin.Context) {
	// Get the full path including /api/files
	path := "/api/files" + c.Param("path")

	// Create transport for HTTP connection to file server
	transport := &http.Transport{
		DialContext: (&net.Dialer{
			Timeout:   30 * time.Second,
			KeepAlive: 30 * time.Second,
		}).DialContext,
		MaxIdleConns:          100,
		IdleConnTimeout:       90 * time.Second,
		TLSHandshakeTimeout:   10 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
	}

	// Target file server URL
	target := fmt.Sprintf("http://127.0.0.1:%d", p.fileServerPort)

	// Create reverse proxy
	proxy := &httputil.ReverseProxy{
		Director: func(req *http.Request) {
			req.URL.Scheme = "http"
			req.URL.Host = fmt.Sprintf("127.0.0.1:%d", p.fileServerPort)
			req.URL.Path = path
			req.URL.RawQuery = c.Request.URL.RawQuery
			req.Host = req.URL.Host

			// Copy headers
			for key, values := range c.Request.Header {
				for _, value := range values {
					req.Header.Set(key, value)
				}
			}
		},
		Transport: transport,
		ModifyResponse: func(resp *http.Response) error {
			// Add CORS headers to response
			resp.Header.Set("Access-Control-Allow-Origin", "*")
			return nil
		},
		ErrorHandler: func(w http.ResponseWriter, r *http.Request, err error) {
			http.Error(w, fmt.Sprintf("File server proxy error: %v", err), http.StatusBadGateway)
		},
	}

	// Handle streaming for file downloads
	if strings.Contains(path, "/download") {
		p.handleStreamingProxy(c, target, path)
		return
	}

	proxy.ServeHTTP(c.Writer, c.Request)
}

// handleStreamingProxy handles streaming responses for large file downloads
func (p *ProxyServer) handleStreamingProxy(c *gin.Context, target, path string) {
	// Build the full URL
	fullURL := fmt.Sprintf("%s%s", target, path)
	if c.Request.URL.RawQuery != "" {
		fullURL += "?" + c.Request.URL.RawQuery
	}

	// Create request
	req, err := http.NewRequest(c.Request.Method, fullURL, c.Request.Body)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Copy headers
	for key, values := range c.Request.Header {
		for _, value := range values {
			req.Header.Set(key, value)
		}
	}

	// Make request
	client := &http.Client{
		Timeout: 0, // No timeout for streaming
	}
	resp, err := client.Do(req)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
		return
	}
	defer resp.Body.Close()

	// Copy response headers
	for key, values := range resp.Header {
		for _, value := range values {
			c.Header(key, value)
		}
	}

	// Set status code
	c.Status(resp.StatusCode)

	// Stream the response body
	io.Copy(c.Writer, resp.Body)
}

// handleHealth returns a health check response
func (p *ProxyServer) handleHealth(c *gin.Context) {
	// Check Docker socket
	dockerOK := p.checkDockerSocket()

	// Check file server
	fileServerOK := p.checkFileServer()

	status := "healthy"
	httpStatus := http.StatusOK
	if !dockerOK || !fileServerOK {
		status = "degraded"
		httpStatus = http.StatusServiceUnavailable
	}

	c.JSON(httpStatus, gin.H{
		"status": status,
		"services": gin.H{
			"docker":     dockerOK,
			"fileServer": fileServerOK,
		},
	})
}

// handleInfo returns proxy information
func (p *ProxyServer) handleInfo(c *gin.Context) {
	socketPath := p.GetDockerSocketPath()
	c.JSON(http.StatusOK, gin.H{
		"name":    "DevMate Proxy",
		"version": "1.0.0",
		"routes": gin.H{
			"docker":     "/docker/*",
			"fileServer": "/api/files/*",
		},
		"port":             p.port,
		"dockerSocketPath": socketPath,
	})
}

// handleListDockerSockets returns available Docker sockets
func (p *ProxyServer) handleListDockerSockets(c *gin.Context) {
	available := config.GetAvailableDockerSockets()
	currentPath := p.GetDockerSocketPath()

	type socketInfo struct {
		Path      string `json:"path"`
		Available bool   `json:"available"`
		Active    bool   `json:"active"`
	}

	sockets := make([]socketInfo, 0)

	// Add all known socket paths
	for _, path := range config.DockerSocketPaths {
		isAvailable := false
		for _, avail := range available {
			if avail == path {
				isAvailable = true
				break
			}
		}
		sockets = append(sockets, socketInfo{
			Path:      path,
			Available: isAvailable,
			Active:    path == currentPath,
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"sockets":       sockets,
		"currentSocket": currentPath,
	})
}

// handleSelectDockerSocket allows switching the active Docker socket
func (p *ProxyServer) handleSelectDockerSocket(c *gin.Context) {
	var req struct {
		Path string `json:"path" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "path is required"})
		return
	}

	// Verify the socket is available
	available := config.GetAvailableDockerSockets()
	isAvailable := false
	for _, path := range available {
		if path == req.Path {
			isAvailable = true
			break
		}
	}

	if !isAvailable {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "Docker socket not available",
			"path":    req.Path,
			"message": "The specified Docker socket does not exist or is not accessible",
		})
		return
	}

	// Set the new socket path
	oldPath := p.GetDockerSocketPath()
	p.SetDockerSocketPath(req.Path)

	fmt.Printf("Docker socket changed: %s -> %s\n", oldPath, req.Path)

	c.JSON(http.StatusOK, gin.H{
		"message": "Docker socket updated",
		"oldPath": oldPath,
		"newPath": req.Path,
	})
}

// checkDockerSocket checks if Docker socket is accessible
func (p *ProxyServer) checkDockerSocket() bool {
	socketPath := p.GetDockerSocketPath()
	conn, err := net.DialTimeout("unix", socketPath, 2*time.Second)
	if err != nil {
		return false
	}
	conn.Close()
	return true
}

// checkFileServer checks if file server is accessible
func (p *ProxyServer) checkFileServer() bool {
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get(fmt.Sprintf("http://127.0.0.1:%d/api/files/list?path=/", p.fileServerPort))
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	return resp.StatusCode == http.StatusOK
}
