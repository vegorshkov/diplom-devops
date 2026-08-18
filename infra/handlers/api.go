package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/vegorshkov/infra/models"
)

func HealthHandler(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func InfrastructureHandler(w http.ResponseWriter, _ *http.Request) {
	snapshot := models.InfrastructureSnapshot{
		Nodes:     getNodesStatus(),
		Services:  getServicesStatus(),
		Timestamp: time.Now().Format(time.RFC3339),
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(snapshot)
}

func NodesHandler(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(getNodesStatus())
}

func ServicesHandler(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(getServicesStatus())
}
