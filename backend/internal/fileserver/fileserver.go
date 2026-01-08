package fileserver

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
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
	mux := http.NewServeMux()

	// Register routes
	mux.HandleFunc("/api/files/list", fs.corsMiddleware(fs.handleList))
	mux.HandleFunc("/api/files/download", fs.corsMiddleware(fs.handleDownload))
	mux.HandleFunc("/api/files/upload", fs.corsMiddleware(fs.handleUpload))
	mux.HandleFunc("/api/files/mkdir", fs.corsMiddleware(fs.handleMkdir))
	mux.HandleFunc("/api/files/delete", fs.corsMiddleware(fs.handleDelete))
	mux.HandleFunc("/api/files/rename", fs.corsMiddleware(fs.handleRename))
	mux.HandleFunc("/api/files/info", fs.corsMiddleware(fs.handleInfo))
	mux.HandleFunc("/api/files/search", fs.corsMiddleware(fs.handleSearch))

	addr := fmt.Sprintf(":%d", fs.port)
	fmt.Printf("File server starting on port %d\n", fs.port)
	fmt.Printf("Serving files from: %s\n", fs.rootPath)

	return http.ListenAndServe(addr, mux)
}

// corsMiddleware adds CORS headers to responses
func (fs *FileServer) corsMiddleware(handler http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		handler(w, r)
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
func (fs *FileServer) handleList(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	requestedPath := r.URL.Query().Get("path")
	if requestedPath == "" {
		requestedPath = "/"
	}

	fullPath, err := fs.resolvePath(requestedPath)
	if err != nil {
		http.Error(w, err.Error(), http.StatusForbidden)
		return
	}

	entries, err := os.ReadDir(fullPath)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to read directory: %v", err), http.StatusInternalServerError)
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

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"files": files,
		"path":  requestedPath,
	})
}

// handleDownload downloads a file
func (fs *FileServer) handleDownload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	requestedPath := r.URL.Query().Get("path")
	if requestedPath == "" {
		http.Error(w, "Path is required", http.StatusBadRequest)
		return
	}

	fullPath, err := fs.resolvePath(requestedPath)
	if err != nil {
		http.Error(w, err.Error(), http.StatusForbidden)
		return
	}

	info, err := os.Stat(fullPath)
	if err != nil {
		http.Error(w, "File not found", http.StatusNotFound)
		return
	}

	if info.IsDir() {
		http.Error(w, "Cannot download directory", http.StatusBadRequest)
		return
	}

	file, err := os.Open(fullPath)
	if err != nil {
		http.Error(w, "Failed to open file", http.StatusInternalServerError)
		return
	}
	defer file.Close()

	filename := filepath.Base(fullPath)
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", filename))
	w.Header().Set("Content-Type", getMimeType(filename))
	w.Header().Set("Content-Length", fmt.Sprintf("%d", info.Size()))

	io.Copy(w, file)
}

// handleUpload handles file uploads
func (fs *FileServer) handleUpload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Parse multipart form (32 MB max)
	err := r.ParseMultipartForm(32 << 20)
	if err != nil {
		http.Error(w, "Failed to parse form", http.StatusBadRequest)
		return
	}

	// Get target path
	targetPath := r.FormValue("path")
	if targetPath == "" {
		targetPath = "/"
	}

	fullPath, err := fs.resolvePath(targetPath)
	if err != nil {
		http.Error(w, err.Error(), http.StatusForbidden)
		return
	}

	// Get uploaded file
	file, handler, err := r.FormFile("file")
	if err != nil {
		http.Error(w, "Failed to get uploaded file", http.StatusBadRequest)
		return
	}
	defer file.Close()

	// Create destination file
	destPath := filepath.Join(fullPath, handler.Filename)
	if !strings.HasPrefix(destPath, fs.rootPath) {
		http.Error(w, "Access denied", http.StatusForbidden)
		return
	}

	destFile, err := os.Create(destPath)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to create file: %v", err), http.StatusInternalServerError)
		return
	}
	defer destFile.Close()

	// Copy file contents
	_, err = io.Copy(destFile, file)
	if err != nil {
		http.Error(w, "Failed to save file", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message":  "File uploaded successfully",
		"filename": handler.Filename,
		"path":     filepath.Join(targetPath, handler.Filename),
	})
}

// handleMkdir creates a new directory
func (fs *FileServer) handleMkdir(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		Path string `json:"path"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	fullPath, err := fs.resolvePath(req.Path)
	if err != nil {
		http.Error(w, err.Error(), http.StatusForbidden)
		return
	}

	if err := os.MkdirAll(fullPath, 0755); err != nil {
		http.Error(w, fmt.Sprintf("Failed to create directory: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message": "Directory created successfully",
		"path":    req.Path,
	})
}

// handleDelete deletes a file or directory
func (fs *FileServer) handleDelete(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	requestedPath := r.URL.Query().Get("path")
	if requestedPath == "" {
		http.Error(w, "Path is required", http.StatusBadRequest)
		return
	}

	recursive := r.URL.Query().Get("recursive") == "true"

	fullPath, err := fs.resolvePath(requestedPath)
	if err != nil {
		http.Error(w, err.Error(), http.StatusForbidden)
		return
	}

	// Prevent deleting root
	if fullPath == fs.rootPath {
		http.Error(w, "Cannot delete root directory", http.StatusForbidden)
		return
	}

	var deleteErr error
	if recursive {
		deleteErr = os.RemoveAll(fullPath)
	} else {
		deleteErr = os.Remove(fullPath)
	}

	if deleteErr != nil {
		http.Error(w, fmt.Sprintf("Failed to delete: %v", deleteErr), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message": "Deleted successfully",
		"path":    requestedPath,
	})
}

// handleRename renames a file or directory
func (fs *FileServer) handleRename(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		OldPath string `json:"oldPath"`
		NewPath string `json:"newPath"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	oldFullPath, err := fs.resolvePath(req.OldPath)
	if err != nil {
		http.Error(w, err.Error(), http.StatusForbidden)
		return
	}

	newFullPath, err := fs.resolvePath(req.NewPath)
	if err != nil {
		http.Error(w, err.Error(), http.StatusForbidden)
		return
	}

	if err := os.Rename(oldFullPath, newFullPath); err != nil {
		http.Error(w, fmt.Sprintf("Failed to rename: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message": "Renamed successfully",
		"oldPath": req.OldPath,
		"newPath": req.NewPath,
	})
}

// handleInfo gets file/directory information
func (fs *FileServer) handleInfo(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	requestedPath := r.URL.Query().Get("path")
	if requestedPath == "" {
		http.Error(w, "Path is required", http.StatusBadRequest)
		return
	}

	fullPath, err := fs.resolvePath(requestedPath)
	if err != nil {
		http.Error(w, err.Error(), http.StatusForbidden)
		return
	}

	info, err := os.Stat(fullPath)
	if err != nil {
		http.Error(w, "File not found", http.StatusNotFound)
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

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(item)
}

// handleSearch searches for files
func (fs *FileServer) handleSearch(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	query := r.URL.Query().Get("query")
	if query == "" {
		http.Error(w, "Query is required", http.StatusBadRequest)
		return
	}

	basePath := r.URL.Query().Get("basePath")
	if basePath == "" {
		basePath = "/"
	}

	fullBasePath, err := fs.resolvePath(basePath)
	if err != nil {
		http.Error(w, err.Error(), http.StatusForbidden)
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

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
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
