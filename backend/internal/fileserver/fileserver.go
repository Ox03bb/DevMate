package fileserver

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

// FileItem represents a file or directory
type FileItem struct {
	Name        string    `json:"name"`
	Path        string    `json:"path"`
	IsDirectory bool      `json:"isDirectory"`
	Size        int64     `json:"size"`
	ModifiedAt  time.Time `json:"modifiedAt"`
	Extension   string    `json:"extension,omitempty"`
	MimeType    string    `json:"mimeType,omitempty"`
}

// FileServer handles file sharing operations
type FileServer struct {
	rootPath string
	port     int
	router   *gin.Engine
}

// NewFileServer creates a new file server instance
func NewFileServer(rootPath string, port int) *FileServer {
	// Default to user's home directory if not specified
	if rootPath == "" {
		homeDir, err := os.UserHomeDir()
		if err != nil {
			rootPath = "/"
		} else {
			rootPath = homeDir
		}
	}

	return &FileServer{
		rootPath: rootPath,
		port:     port,
	}
}

// Start starts the file server
func (fs *FileServer) Start() error {
	gin.SetMode(gin.ReleaseMode)
	fs.router = gin.New()
	fs.router.Use(gin.Recovery())
	fs.router.Use(fs.corsMiddleware())

	// Register routes
	api := fs.router.Group("/api/files")
	{
		api.GET("/list", fs.handleList)
		api.GET("/download", fs.handleDownload)
		api.POST("/upload", fs.handleUpload)
		api.POST("/mkdir", fs.handleMkdir)
		api.DELETE("/delete", fs.handleDelete)
		api.POST("/rename", fs.handleRename)
		api.GET("/info", fs.handleInfo)
		api.GET("/search", fs.handleSearch)
	}

	addr := fmt.Sprintf(":%d", fs.port)
	fmt.Printf("File server starting on port %d\n", fs.port)
	fmt.Printf("Serving files from: %s\n", fs.rootPath)

	return fs.router.Run(addr)
}

// corsMiddleware adds CORS headers to responses
func (fs *FileServer) corsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type")
		c.Header("Access-Control-Expose-Headers", "Content-Disposition, Content-Length")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusOK)
			return
		}

		c.Next()
	}
}

// resolvePath safely resolves a path relative to the root
func (fs *FileServer) resolvePath(requestedPath string) (string, error) {
	// Clean the path to prevent directory traversal
	cleanPath := filepath.Clean(requestedPath)

	// Join with root path
	fullPath := filepath.Join(fs.rootPath, cleanPath)

	// Ensure the path is within the root
	if !strings.HasPrefix(fullPath, fs.rootPath) {
		return "", fmt.Errorf("access denied: path outside root directory")
	}

	return fullPath, nil
}

// handleList lists files in a directory
func (fs *FileServer) handleList(c *gin.Context) {
	requestedPath := c.DefaultQuery("path", "/")

	fullPath, err := fs.resolvePath(requestedPath)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		return
	}

	entries, err := os.ReadDir(fullPath)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to read directory: %v", err)})
		return
	}

	files := make([]FileItem, 0, len(entries))
	for _, entry := range entries {
		info, err := entry.Info()
		if err != nil {
			continue
		}

		// Skip hidden files (starting with .)
		if strings.HasPrefix(entry.Name(), ".") {
			continue
		}

		item := FileItem{
			Name:        entry.Name(),
			Path:        filepath.Join(requestedPath, entry.Name()),
			IsDirectory: entry.IsDir(),
			Size:        info.Size(),
			ModifiedAt:  info.ModTime(),
		}

		if !entry.IsDir() {
			item.Extension = strings.TrimPrefix(filepath.Ext(entry.Name()), ".")
			item.MimeType = getMimeType(entry.Name())
		}

		files = append(files, item)
	}

	c.JSON(http.StatusOK, gin.H{
		"files": files,
		"path":  requestedPath,
	})
}

// handleDownload downloads a file
func (fs *FileServer) handleDownload(c *gin.Context) {
	requestedPath := c.Query("path")
	if requestedPath == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Path is required"})
		return
	}

	fullPath, err := fs.resolvePath(requestedPath)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		return
	}

	info, err := os.Stat(fullPath)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "File not found"})
		return
	}

	if info.IsDir() {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot download directory"})
		return
	}

	filename := filepath.Base(fullPath)
	c.FileAttachment(fullPath, filename)
}

// handleUpload handles file uploads
func (fs *FileServer) handleUpload(c *gin.Context) {
	// Get target path
	targetPath := c.DefaultPostForm("path", "/")

	fullPath, err := fs.resolvePath(targetPath)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		return
	}

	// Verify target directory exists
	info, err := os.Stat(fullPath)
	if err != nil {
		if os.IsNotExist(err) {
			// Create the directory if it doesn't exist
			if err := os.MkdirAll(fullPath, 0755); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to create directory: %v", err)})
				return
			}
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to access path: %v", err)})
			return
		}
	} else if !info.IsDir() {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Target path is not a directory"})
		return
	}

	// Get uploaded file
	file, header, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Failed to get uploaded file: %v", err)})
		return
	}
	defer file.Close()

	// Create destination file
	destPath := filepath.Join(fullPath, header.Filename)
	if !strings.HasPrefix(destPath, fs.rootPath) {
		c.JSON(http.StatusForbidden, gin.H{"error": "Access denied"})
		return
	}

	destFile, err := os.Create(destPath)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to create file: %v", err)})
		return
	}
	defer destFile.Close()

	// Copy file contents
	_, err = io.Copy(destFile, file)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save file"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":  "File uploaded successfully",
		"filename": header.Filename,
		"path":     filepath.Join(targetPath, header.Filename),
	})
}

// handleMkdir creates a new directory
func (fs *FileServer) handleMkdir(c *gin.Context) {
	var req struct {
		Path string `json:"path" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	fullPath, err := fs.resolvePath(req.Path)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		return
	}

	if err := os.MkdirAll(fullPath, 0755); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to create directory: %v", err)})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Directory created successfully",
		"path":    req.Path,
	})
}

// handleDelete deletes a file or directory
func (fs *FileServer) handleDelete(c *gin.Context) {
	requestedPath := c.Query("path")
	if requestedPath == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Path is required"})
		return
	}

	recursive := c.Query("recursive") == "true"

	fullPath, err := fs.resolvePath(requestedPath)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		return
	}

	// Prevent deleting root
	if fullPath == fs.rootPath {
		c.JSON(http.StatusForbidden, gin.H{"error": "Cannot delete root directory"})
		return
	}

	var deleteErr error
	if recursive {
		deleteErr = os.RemoveAll(fullPath)
	} else {
		deleteErr = os.Remove(fullPath)
	}

	if deleteErr != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to delete: %v", deleteErr)})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Deleted successfully",
		"path":    requestedPath,
	})
}

// handleRename renames a file or directory
func (fs *FileServer) handleRename(c *gin.Context) {
	var req struct {
		OldPath string `json:"oldPath" binding:"required"`
		NewPath string `json:"newPath" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	oldFullPath, err := fs.resolvePath(req.OldPath)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		return
	}

	newFullPath, err := fs.resolvePath(req.NewPath)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		return
	}

	if err := os.Rename(oldFullPath, newFullPath); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to rename: %v", err)})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Renamed successfully",
		"oldPath": req.OldPath,
		"newPath": req.NewPath,
	})
}

// handleInfo gets file/directory information
func (fs *FileServer) handleInfo(c *gin.Context) {
	requestedPath := c.Query("path")
	if requestedPath == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Path is required"})
		return
	}

	fullPath, err := fs.resolvePath(requestedPath)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		return
	}

	info, err := os.Stat(fullPath)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "File not found"})
		return
	}

	item := FileItem{
		Name:        info.Name(),
		Path:        requestedPath,
		IsDirectory: info.IsDir(),
		Size:        info.Size(),
		ModifiedAt:  info.ModTime(),
	}

	if !info.IsDir() {
		item.Extension = strings.TrimPrefix(filepath.Ext(info.Name()), ".")
		item.MimeType = getMimeType(info.Name())
	}

	c.JSON(http.StatusOK, item)
}

// handleSearch searches for files
func (fs *FileServer) handleSearch(c *gin.Context) {
	query := c.Query("query")
	if query == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Query is required"})
		return
	}

	basePath := c.DefaultQuery("basePath", "/")

	fullBasePath, err := fs.resolvePath(basePath)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		return
	}

	var results []FileItem
	queryLower := strings.ToLower(query)

	filepath.Walk(fullBasePath, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}

		// Skip hidden files
		if strings.HasPrefix(info.Name(), ".") {
			if info.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}

		// Match query
		if strings.Contains(strings.ToLower(info.Name()), queryLower) {
			relativePath := strings.TrimPrefix(path, fs.rootPath)
			if relativePath == "" {
				relativePath = "/"
			}

			item := FileItem{
				Name:        info.Name(),
				Path:        relativePath,
				IsDirectory: info.IsDir(),
				Size:        info.Size(),
				ModifiedAt:  info.ModTime(),
			}

			if !info.IsDir() {
				item.Extension = strings.TrimPrefix(filepath.Ext(info.Name()), ".")
				item.MimeType = getMimeType(info.Name())
			}

			results = append(results, item)
		}

		// Limit results
		if len(results) >= 100 {
			return filepath.SkipAll
		}

		return nil
	})

	c.JSON(http.StatusOK, gin.H{
		"files": results,
		"query": query,
	})
}

// getMimeType returns the MIME type for a file
func getMimeType(filename string) string {
	ext := strings.ToLower(filepath.Ext(filename))
	mimeTypes := map[string]string{
		".txt":  "text/plain",
		".html": "text/html",
		".css":  "text/css",
		".js":   "text/javascript",
		".json": "application/json",
		".xml":  "application/xml",
		".pdf":  "application/pdf",
		".zip":  "application/zip",
		".tar":  "application/x-tar",
		".gz":   "application/gzip",
		".jpg":  "image/jpeg",
		".jpeg": "image/jpeg",
		".png":  "image/png",
		".gif":  "image/gif",
		".svg":  "image/svg+xml",
		".webp": "image/webp",
		".ico":  "image/x-icon",
		".mp3":  "audio/mpeg",
		".wav":  "audio/wav",
		".mp4":  "video/mp4",
		".webm": "video/webm",
		".avi":  "video/x-msvideo",
		".mov":  "video/quicktime",
		".doc":  "application/msword",
		".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
		".xls":  "application/vnd.ms-excel",
		".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
		".ppt":  "application/vnd.ms-powerpoint",
		".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
	}

	if mime, ok := mimeTypes[ext]; ok {
		return mime
	}
	return "application/octet-stream"
}
