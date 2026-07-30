package models

// NodeStatus — статус узла Kubernetes
type NodeStatus struct {
	Name      string  `json:"name"`
	Status    string  `json:"status"`
	Role      string  `json:"role"`
	CPU       float64 `json:"cpu"`
	RAM       float64 `json:"ram"`
	Pods      int     `json:"pods"`
	Uptime    string  `json:"uptime"`
	UpdatedAt string  `json:"updated_at"`
}

// ServiceStatus — статус внешнего сервиса
type ServiceStatus struct {
	Name    string `json:"name"`
	Status  string `json:"status"`
	URL     string `json:"url"`
	Message string `json:"message"`
}

// InfrastructureSnapshot — полный снимок состояния
type InfrastructureSnapshot struct {
	Nodes            []NodeStatus    `json:"nodes"`
	Services         []ServiceStatus `json:"services"`
	DeployInProgress bool            `json:"deploy_in_progress"`
	DeployVersion    string          `json:"deploy_version,omitempty"`
	DeployProgress   int             `json:"deploy_progress,omitempty"`
	Timestamp        string          `json:"timestamp"`
}

// WSMessage — сообщение WebSocket
type WSMessage struct {
	Type    string      `json:"type"`
	Payload interface{} `json:"payload"`
}
