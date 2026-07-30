package handlers

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/vegorshkov/infra/models"
)

var (
	upgrader = websocket.Upgrader{
		CheckOrigin: func(r *http.Request) bool { return true },
	}
	clients   = make(map[*websocket.Conn]bool)
	clientsMu sync.Mutex
)

func WebSocketHandler(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("WebSocket upgrade error:", err)
		return
	}
	defer conn.Close()

	clientsMu.Lock()
	clients[conn] = true
	clientsMu.Unlock()

	log.Printf("WebSocket client connected (%d total)\n", len(clients))

	welcome := models.WSMessage{
		Type:    "connected",
		Payload: map[string]interface{}{"message": "Connected to Infra", "clients": len(clients)},
	}
	conn.WriteJSON(welcome)

	for {
		_, msg, err := conn.ReadMessage()
		if err != nil {
			break
		}
		var wsMsg models.WSMessage
		if err := json.Unmarshal(msg, &wsMsg); err != nil {
			continue
		}
		switch wsMsg.Type {
		case "ping":
			conn.WriteJSON(models.WSMessage{Type: "pong"})
		case "get_snapshot":
			snapshot := models.InfrastructureSnapshot{
				Nodes:     getNodesStatus(),
				Services:  getServicesStatus(),
				Timestamp: time.Now().Format(time.RFC3339),
			}
			conn.WriteJSON(models.WSMessage{Type: "snapshot", Payload: snapshot})
		}
	}

	clientsMu.Lock()
	delete(clients, conn)
	clientsMu.Unlock()
	log.Printf("WebSocket client disconnected (%d total)\n", len(clients))
}
