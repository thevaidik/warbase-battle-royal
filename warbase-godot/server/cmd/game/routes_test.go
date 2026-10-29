package main

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
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

func TestColyseusCandidateURLValidation(t *testing.T) {
	for _, valid := range []string{"http://127.0.0.1:8081", "https://colyseus.example:8443"} {
		if _, err := parseColyseusCandidateURL(valid); err != nil {
			t.Errorf("valid candidate URL %q rejected: %v", valid, err)
		}
	}
	for _, invalid := range []string{"", "ws://colyseus.example", "https:///missing-host", "https://user:secret@colyseus.example", "https://colyseus.example?x=1", "https://colyseus.example#fragment"} {
		if _, err := parseColyseusCandidateURL(invalid); err == nil {
			t.Errorf("invalid candidate URL %q accepted", invalid)
		}
	}
}

func TestColyseusCandidateHTTPProxyStripsPrefix(t *testing.T) {
	type observedRequest struct{ path, query, prefix string }
	observed := make(chan observedRequest, 1)
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		observed <- observedRequest{r.URL.Path, r.URL.RawQuery, r.Header.Get("X-Forwarded-Prefix")}
		w.WriteHeader(http.StatusOK)
		_, _ = io.WriteString(w, "matchmaking")
	}))
	defer upstream.Close()

	app := testApp(t)
	app.config.colyseusURL = upstream.URL
	response := httptest.NewRecorder()
	app.routes().ServeHTTP(response, httptest.NewRequest(http.MethodPost, "/colyseus/matchmake/joinOrCreate/battle?room=industrial-public", strings.NewReader("{}")))
	if response.Code != http.StatusOK || response.Body.String() != "matchmaking" {
		t.Fatalf("unexpected proxy response: %d %q", response.Code, response.Body.String())
	}
	got := <-observed
	if got.path != "/matchmake/joinOrCreate/battle" || got.query != "room=industrial-public" || got.prefix != "/colyseus" {
		t.Fatalf("prefix was not stripped/preserved correctly: %+v", got)
	}
}

func TestColyseusCandidateRootMatchmakeProxyPreservesPath(t *testing.T) {
	type observedRequest struct{ path, query, prefix string }
	observed := make(chan observedRequest, 1)
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		observed <- observedRequest{r.URL.Path, r.URL.RawQuery, r.Header.Get("X-Forwarded-Prefix")}
		w.WriteHeader(http.StatusCreated)
		_, _ = io.WriteString(w, `{"room":{"roomId":"candidate"}}`)
	}))
	defer upstream.Close()

	app := testApp(t)
	app.config.colyseusURL = upstream.URL
	response := httptest.NewRecorder()
	app.routes().ServeHTTP(response, httptest.NewRequest(http.MethodPost, "/matchmake/joinOrCreate/battle?room=industrial-public", strings.NewReader(`{"username":"qa"}`)))
	if response.Code != http.StatusCreated || !strings.Contains(response.Body.String(), "candidate") {
		t.Fatalf("unexpected root matchmaking proxy response: %d %q", response.Code, response.Body.String())
	}
	got := <-observed
	if got.path != "/matchmake/joinOrCreate/battle" || got.query != "room=industrial-public" || got.prefix != "/colyseus" {
		t.Fatalf("root matchmaking path was not preserved: %+v", got)
	}
}

func TestColyseusCandidateWebSocketProxy(t *testing.T) {
	upgrader := websocket.Upgrader{CheckOrigin: func(*http.Request) bool { return true }}
	seenPath := make(chan string, 1)
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seenPath <- r.URL.Path
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			return
		}
		defer conn.Close()
		_ = conn.SetReadDeadline(time.Now().Add(2 * time.Second))
		kind, message, err := conn.ReadMessage()
		if err == nil {
			_ = conn.WriteMessage(kind, message)
		}
	}))
	defer upstream.Close()

	app := testApp(t)
	app.config.colyseusURL = upstream.URL
	proxyServer := httptest.NewServer(app.routes())
	defer proxyServer.Close()
	wsURL := "ws" + strings.TrimPrefix(proxyServer.URL, "http") + "/colyseus/matchmake/seat-reservation?token=abc"
	conn, response, err := websocket.DefaultDialer.DialContext(context.Background(), wsURL, nil)
	if err != nil {
		if response != nil {
			t.Fatalf("websocket proxy handshake failed: %v (HTTP %d)", err, response.StatusCode)
		}
		t.Fatal(err)
	}
	defer conn.Close()
	if err := conn.SetReadDeadline(time.Now().Add(2 * time.Second)); err != nil {
		t.Fatal(err)
	}
	if err := conn.WriteMessage(websocket.TextMessage, []byte("seat")); err != nil {
		t.Fatal(err)
	}
	_, echoed, err := conn.ReadMessage()
	if err != nil || string(echoed) != "seat" {
		t.Fatalf("websocket echo failed: message=%q err=%v", echoed, err)
	}
	select {
	case path := <-seenPath:
		if path != "/matchmake/seat-reservation" {
			t.Fatalf("upstream websocket path retained prefix: %q", path)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("upstream did not receive websocket request")
	}
}

func TestColyseusCandidateBarePathRedirects(t *testing.T) {
	app := testApp(t)
	app.config.colyseusURL = "http://127.0.0.1:8081"
	response := httptest.NewRecorder()
	app.routes().ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/colyseus", nil))
	if response.Code != http.StatusPermanentRedirect || response.Header().Get("Location") != "/colyseus/" {
		t.Fatalf("expected /colyseus redirect, got %d location=%q", response.Code, response.Header().Get("Location"))
	}

	app = testApp(t)
	app.config.staticDir = t.TempDir()
	response = httptest.NewRecorder()
	app.routes().ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/colyseus/", nil))
	if response.Code != http.StatusNotFound || response.Header().Get("Location") != "" {
		t.Fatalf("unset candidate URL unexpectedly mounted a proxy route: %d location=%q", response.Code, response.Header().Get("Location"))
	}
}
