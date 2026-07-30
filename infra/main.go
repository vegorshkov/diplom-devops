package main

import (
	"log"
	"net/http"
	"os"

	"github.com/vegorshkov/infra/handlers"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	mux := http.NewServeMux()

	// Статические файлы (фронтенд)
	fs := http.FileServer(http.Dir("static"))
	mux.Handle("/", fs)

	// REST API
	mux.HandleFunc("/api/health", handlers.HealthHandler)
	mux.HandleFunc("/api/infrastructure", handlers.InfrastructureHandler)
	mux.HandleFunc("/api/nodes", handlers.NodesHandler)
	mux.HandleFunc("/api/services", handlers.ServicesHandler)

	// WebSocket
	mux.HandleFunc("/ws", handlers.WebSocketHandler)

	log.Printf("Infra server starting on :%s\n", port)
	log.Fatal(http.ListenAndServe(":"+port, mux))
}
