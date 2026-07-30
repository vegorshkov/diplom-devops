package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/vegorshkov/infra/models"
)

func HealthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func InfrastructureHandler(w http.ResponseWriter, r *http.Request) {
	snapshot := models.InfrastructureSnapshot{
		Nodes:     getNodesStatus(),
		Services:  getServicesStatus(),
		Timestamp: time.Now().Format(time.RFC3339),
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(snapshot)
}

func NodesHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(getNodesStatus())
}

func ServicesHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(getServicesStatus())
}

func getNodesStatus() []models.NodeStatus {
	return []models.NodeStatus{
		{Name: "k8s-master-01", Status: "Ready", Role: "master", CPU: 45.2, RAM: 62.1, Pods: 12, Uptime: "5d 12h", UpdatedAt: time.Now().Format(time.RFC3339)},
		{Name: "k8s-worker-01", Status: "Ready", Role: "worker", CPU: 32.8, RAM: 48.5, Pods: 8, Uptime: "5d 11h", UpdatedAt: time.Now().Format(time.RFC3339)},
		{Name: "k8s-worker-02", Status: "Ready", Role: "worker", CPU: 28.1, RAM: 41.3, Pods: 6, Uptime: "5d 10h", UpdatedAt: time.Now().Format(time.RFC3339)},
	}
}

func getServicesStatus() []models.ServiceStatus {
	return []models.ServiceStatus{
		{Name: "NAT Instance", Status: "ok", URL: "158.160.2.211", Message: "Внешний IP доступен"},
		{Name: "Grafana", Status: "ok", URL: "https://158.160.2.211/grafana", Message: "Дашборды активны"},
		{Name: "GitLab", Status: "ok", URL: "https://158.160.2.211/gitlab", Message: "CI/CD работает"},
		{Name: "Basic Auth", Status: "ok", URL: "https://158.160.2.211", Message: "NGINX прокси активен"},
	}
}
