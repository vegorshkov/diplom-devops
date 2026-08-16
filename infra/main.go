package main

import (
	"log"
	"net/http"
	"os"
	"time"

	"github.com/vegorshkov/infra/handlers"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	metricsPort := os.Getenv("METRICS_PORT")
	if metricsPort == "" {
		metricsPort = "9090"
	}

	appVersion := os.Getenv("APP_VERSION")
	if appVersion == "" {
		appVersion = "unknown"
	}

	mux := http.NewServeMux()

	fs := http.FileServer(http.Dir("static"))
	mux.Handle("/", fs)

	mux.HandleFunc("/api/health", handlers.HealthHandler)
	mux.HandleFunc("/api/infrastructure", handlers.InfrastructureHandler)
	mux.HandleFunc("/api/nodes", handlers.NodesHandler)
	mux.HandleFunc("/api/services", handlers.ServicesHandler)

	mux.HandleFunc("/ws", handlers.WebSocketHandler)

	go startMetricsServer(metricsPort, appVersion)

	server := &http.Server{
		Addr:              ":" + port,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Printf("Infra server starting on :%s\n", port)
	log.Fatal(server.ListenAndServe())
}
