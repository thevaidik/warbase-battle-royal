package main

import (
	"fmt"
	"mime"
	"net/http"
	"net/http/httputil"
	"net/http/pprof"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

var immutableAsset = regexp.MustCompile(`^(engine-[0-9a-f]{16}\.(wasm|js|audio\.worklet\.js|audio\.position\.worklet\.js)|(game|map-football)-[0-9a-f]{16}\.pck)$`)

func init() {
	_ = mime.AddExtensionType(".wasm", "application/wasm")
	_ = mime.AddExtensionType(".pck", "application/octet-stream")
	_ = mime.AddExtensionType(".js", "application/javascript")
}

// Refresh the deadline on each chunk: large game packs must be allowed to
// download over a slow connection without allowing a stalled write forever.
type progressAssetWriter struct{ http.ResponseWriter }

func (w progressAssetWriter) Write(data []byte) (int, error) {
	_ = http.NewResponseController(w.ResponseWriter).SetWriteDeadline(time.Now().Add(30 * time.Second))
	return w.ResponseWriter.Write(data)
}
func (w progressAssetWriter) Unwrap() http.ResponseWriter { return w.ResponseWriter }

func enableCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Accept, Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, Origin")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func (app *application) routes() http.Handler {
	mux := http.NewServeMux()
	if app.config.colyseusURL != "" {
		if target, err := parseColyseusCandidateURL(app.config.colyseusURL); err == nil {
			proxy := httputil.NewSingleHostReverseProxy(target)
			proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
				if app.logger != nil {
					app.logger.PrintError(err, map[string]string{"path": r.URL.Path, "upstream": target.Host})
				}
				http.Error(w, "Colyseus candidate unavailable", http.StatusBadGateway)
			}
			mux.HandleFunc("/colyseus", func(w http.ResponseWriter, r *http.Request) {
				http.Redirect(w, r, "/colyseus/", http.StatusPermanentRedirect)
			})
			mux.Handle("/colyseus/", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				r.URL.Path = strings.TrimPrefix(r.URL.Path, "/colyseus")
				if r.URL.Path == "" {
					r.URL.Path = "/"
				}
				r.URL.RawPath = ""
				r.Header.Set("X-Forwarded-Prefix", "/colyseus")
				r.Header.Set("X-Forwarded-Host", r.Host)
				if r.Header.Get("X-Forwarded-Proto") == "" {
					if r.TLS != nil {
						r.Header.Set("X-Forwarded-Proto", "https")
					} else {
						r.Header.Set("X-Forwarded-Proto", "http")
					}
				}
				proxy.ServeHTTP(w, r)
			}))
			// The pinned Godot SDK always sends HTTP matchmaking requests to
			// /matchmake/... at the origin, even when its WebSocket endpoint has
			// a /colyseus base path. Forward only that otherwise-unused root path
			// while the candidate proxy is enabled; preserve it upstream.
			mux.Handle("/matchmake/", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				r.Header.Set("X-Forwarded-Prefix", "/colyseus")
				r.Header.Set("X-Forwarded-Host", r.Host)
				if r.Header.Get("X-Forwarded-Proto") == "" {
					if r.TLS != nil {
						r.Header.Set("X-Forwarded-Proto", "https")
					} else {
						r.Header.Set("X-Forwarded-Proto", "http")
					}
				}
				proxy.ServeHTTP(w, r)
			}))
		}
	}

	mux.HandleFunc("/healthcheck", app.healthcheckHandler)
	mux.HandleFunc("/connect", app.connectToServerHandler)

	mux.HandleFunc("/api/rooms", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodGet {
			app.listRoomsHandler(w, r)
		} else if r.Method == http.MethodPost {
			app.createRoomHandler(w, r)
		} else {
			app.methodNotAllowedResponse(w, r)
		}
	})

	// Serve the compiled frontend game with transparent pre-compressed gzip support
	distPath := "../client/dist"
	if app.config.env == "production" || os.Getenv("ENV") == "production" {
		distPath = "/app/dist"
	}
	if _, err := os.Stat("/app/dist"); err == nil {
		distPath = "/app/dist"
	} else if _, err := os.Stat("dist"); err == nil {
		distPath = "dist"
	}
	if app.config.staticDir != "" {
		distPath = app.config.staticDir
	}
	mux.Handle("/", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("Cross-Origin-Opener-Policy", "same-origin")
		w.Header().Set("Cross-Origin-Embedder-Policy", "require-corp")

		urlPath := r.URL.Path
		if urlPath == "/" || urlPath == "" {
			urlPath = "/index.html"
		}
		cleanPath := filepath.Clean(strings.TrimPrefix(urlPath, "/"))
		targetFile := filepath.Join(distPath, cleanPath)

		// Set Content-Type and Cache-Control based on requested file
		ext := strings.ToLower(filepath.Ext(cleanPath))
		switch ext {
		case ".html":
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
			w.Header().Set("Pragma", "no-cache")
			w.Header().Set("Expires", "0")
		case ".wasm":
			w.Header().Set("Content-Type", "application/wasm")
			w.Header().Set("Cache-Control", "public, max-age=3600")
		case ".pck":
			w.Header().Set("Content-Type", "application/octet-stream")
			w.Header().Set("Cache-Control", "public, max-age=3600")
		case ".js":
			w.Header().Set("Content-Type", "application/javascript")
			w.Header().Set("Cache-Control", "public, max-age=3600")
		case ".png":
			w.Header().Set("Content-Type", "image/png")
			w.Header().Set("Cache-Control", "public, max-age=86400")
		case ".svg":
			w.Header().Set("Content-Type", "image/svg+xml")
			w.Header().Set("Cache-Control", "public, max-age=86400")
		}

		w.Header().Set("Vary", "Accept-Encoding")
		if immutableAsset.MatchString(cleanPath) {
			w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
			w.Header().Set("ETag", `W/"`+cleanPath+`"`)
		}
		br, gz := encodingQuality(r.Header.Get("Accept-Encoding"), "br"), encodingQuality(r.Header.Get("Accept-Encoding"), "gzip")
		encodings := []string{"br", "gzip"}
		if gz > br {
			encodings = []string{"gzip", "br"}
		}
		for _, encoding := range encodings {
			quality, suffix := br, ".br"
			if encoding == "gzip" {
				quality, suffix = gz, ".gz"
			}
			if quality <= 0 {
				continue
			}
			if info, err := os.Stat(targetFile + suffix); err == nil && !info.IsDir() {
				w.Header().Set("Content-Encoding", encoding)
				http.ServeFile(progressAssetWriter{w}, r, targetFile+suffix)
				return
			}
		}

		// Fallback to uncompressed file
		if info, err := os.Stat(targetFile); err == nil && !info.IsDir() {
			http.ServeFile(progressAssetWriter{w}, r, targetFile)
			return
		}

		http.NotFound(w, r)
	}))

	// Profiling only when not production
	if app.config.env != "production" && os.Getenv("ENV") != "production" {
		mux.HandleFunc("/debug/pprof/", pprof.Index)
		mux.HandleFunc("/debug/pprof/cmdline", pprof.Cmdline)
		mux.HandleFunc("/debug/pprof/profile", pprof.Profile)
		mux.HandleFunc("/debug/pprof/symbol", pprof.Symbol)
		mux.HandleFunc("/debug/pprof/trace", pprof.Trace)
	}

	return enableCORS(mux)
}

func parseColyseusCandidateURL(raw string) (*url.URL, error) {
	target, err := url.Parse(strings.TrimSpace(raw))
	if err != nil {
		return nil, fmt.Errorf("invalid COLYSEUS_CANDIDATE_URL: %w", err)
	}
	if (target.Scheme != "http" && target.Scheme != "https") || target.Host == "" || target.Hostname() == "" || target.User != nil || target.RawQuery != "" || target.Fragment != "" || target.Opaque != "" {
		return nil, fmt.Errorf("COLYSEUS_CANDIDATE_URL must be an http(s) URL with a host and no credentials, query, or fragment")
	}
	return target, nil
}
