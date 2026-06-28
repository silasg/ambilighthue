// Command ambilighthue-web is a tiny REST + PWA service that controls a Philips
// TV's ambilight ("HueLamp") on/off, ported from the tvOS app. Stdlib only.
package main

import (
	"embed"
	"io/fs"
	"log"
	"net/http"
	"os"
	"time"

	"ambilighthue/webapp/internal/server"
	"ambilighthue/webapp/internal/store"
	"ambilighthue/webapp/internal/tv"
)

//go:embed all:web
var webFiles embed.FS

func main() {
	addr := ":" + env("PORT", "8080")
	configPath := env("CONFIG_PATH", "/data/config.json")
	apiToken := os.Getenv("API_TOKEN")
	basePath := os.Getenv("BASE_PATH")

	sub, err := fs.Sub(webFiles, "web")
	if err != nil {
		log.Fatalf("embed web: %v", err)
	}
	server.SetStaticFS(sub)

	st := store.New(configPath)
	srv := server.NewWithBasePath(tv.NewClient(), st, apiToken, basePath)

	httpServer := &http.Server{
		Addr:              addr,
		Handler:           srv.Handler(),
		ReadHeaderTimeout: 10 * time.Second,
	}

	if _, ok := st.Get(); ok {
		log.Printf("loaded TV credentials from %s", configPath)
	} else {
		log.Printf("no TV credentials yet; pair via /api/pair/start (config: %s)", configPath)
	}
	if apiToken != "" {
		log.Print("API_TOKEN set; /api/* (except /api/health) require X-API-Token")
	}
	log.Printf("listening on %s", addr)
	log.Fatal(httpServer.ListenAndServe())
}

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
