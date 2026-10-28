package main

import (
	"io"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
	"warbase-server/internal/engine"
	"warbase-server/internal/jsonlog"
)

func testApp(t *testing.T) *application {
	t.Helper()
	return &application{config: config{env: "production"}, logger: jsonlog.New(io.Discard, jsonlog.LevelInfo), match: engine.NewMatch()}
}
func TestProductionDisablesProfiler(t *testing.T) {
	t.Setenv("ENV", "")
	app := testApp(t)
	response := httptest.NewRecorder()
	app.routes().ServeHTTP(response, httptest.NewRequest("GET", "/debug/pprof/", nil))
	if response.Code != 404 {
		t.Fatalf("profiler exposed with --env=production: %d", response.Code)
	}
}
func TestOriginPolicy(t *testing.T) {
	for _, entry := range []struct {
		origin  string
		allowed bool
	}{{"", true}, {"https://war.vaidik.blog", true}, {"https://evil.example", false}, {"http://example.com", true}} {
		request := httptest.NewRequest("GET", "http://example.com/connect", nil)
		request.Header.Set("Origin", entry.origin)
		if upgrader.CheckOrigin(request) != entry.allowed {
			t.Errorf("incorrect policy for %s", entry.origin)
		}
	}
}
func TestRoomValidation(t *testing.T) {
	app := testApp(t)
	for _, body := range []string{`{"name":"bad","map":"missing","mode":"FFA"}`, `{"name":"bad","map":"arena","mode":"INVALID"}`, `{"name":"bad","map":"loft","mode":"FFA"}`, `{"name":"bad","map":"arena","mode":"FFA","timeOfDay":"sunset-ish"}`} {
		response := httptest.NewRecorder()
		app.routes().ServeHTTP(response, httptest.NewRequest("POST", "/api/rooms", strings.NewReader(body)))
		if response.Code != 400 {
			t.Errorf("invalid room accepted: %d", response.Code)
		}
	}
}
func TestStaticExportDirectory(t *testing.T) {
	app := testApp(t)
	directory := t.TempDir()
	app.config.staticDir = directory
	if err := os.WriteFile(filepath.Join(directory, "index.html"), []byte("warbase-export"), 0600); err != nil {
		t.Fatal(err)
	}
	response := httptest.NewRecorder()
	app.routes().ServeHTTP(response, httptest.NewRequest("GET", "/", nil))
	if response.Code != 200 || !strings.Contains(response.Body.String(), "warbase-export") {
		t.Fatal("explicit export directory not served")
	}
}

func TestCompressedImmutableAssets(t *testing.T) {
	app := testApp(t)
	directory := t.TempDir()
	app.config.staticDir = directory
	name := "engine-0123456789abcdef.wasm"
	for suffix, contents := range map[string]string{"": "raw", ".gz": "gzip", ".br": "brotli"} {
		if err := os.WriteFile(filepath.Join(directory, name+suffix), []byte(contents), 0600); err != nil {
			t.Fatal(err)
		}
	}
	for _, entry := range []struct{ accept, encoding, body string }{{"br, gzip", "br", "brotli"}, {"br;q=0,gzip", "gzip", "gzip"}, {"br;q=0.2,gzip;q=0.8", "gzip", "gzip"}, {"identity", "", "raw"}, {"*;q=1,br;q=0", "gzip", "gzip"}} {
		request := httptest.NewRequest("GET", "/"+name, nil)
		request.Header.Set("Accept-Encoding", entry.accept)
		response := httptest.NewRecorder()
		app.routes().ServeHTTP(response, request)
		if response.Code != 200 || response.Header().Get("Content-Encoding") != entry.encoding || response.Body.String() != entry.body {
			t.Fatalf("incorrect encoding for %s", entry.accept)
		}
		if response.Header().Get("Vary") != "Accept-Encoding" || !strings.Contains(response.Header().Get("Cache-Control"), "immutable") {
			t.Fatal("missing safe caching headers")
		}
		if response.Header().Get("Content-Type") != "application/wasm" {
			t.Fatal("encoded asset lost its MIME type")
		}
	}
}

type deadlineResponse struct {
	*httptest.ResponseRecorder
	deadlines []time.Time
}

func (w *deadlineResponse) SetWriteDeadline(deadline time.Time) error {
	w.deadlines = append(w.deadlines, deadline)
	return nil
}
func TestAssetTransferRefreshesDeadlineForEveryChunk(t *testing.T) {
	underlying := &deadlineResponse{ResponseRecorder: httptest.NewRecorder()}
	writer := progressAssetWriter{underlying}
	writer.Write([]byte("one"))
	writer.Write([]byte("two"))
	if len(underlying.deadlines) != 2 || time.Until(underlying.deadlines[1]) < 29*time.Second || underlying.Body.String() != "onetwo" {
		t.Fatal("large asset transfer retains the original whole-response deadline")
	}
}
