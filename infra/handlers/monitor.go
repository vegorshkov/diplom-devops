package handlers

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"sort"
	"strings"
	"sync"
	"time"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	metricsclient "k8s.io/metrics/pkg/client/clientset/versioned"

	"github.com/vegorshkov/infra/models"
)

var (
	kubeClient    kubernetes.Interface
	metricsClient metricsclient.Interface
)

type serviceProbe struct {
	name string
	url  string
}

func init() {
	config, err := rest.InClusterConfig()
	if err != nil {
		log.Printf("Kubernetes in-cluster config unavailable: %v", err)
		return
	}

	kubeClient, err = kubernetes.NewForConfig(config)
	if err != nil {
		log.Printf("Kubernetes client unavailable: %v", err)
		return
	}

	metricsClient, err = metricsclient.NewForConfig(config)
	if err != nil {
		log.Printf("Kubernetes metrics client unavailable: %v", err)
	}
}

func getNodesStatus() []models.NodeStatus {
	now := time.Now()

	if kubeClient == nil {
		return []models.NodeStatus{{
			Name:      "Kubernetes API",
			Status:    "NotReady",
			Role:      "control-plane",
			Uptime:    "API unavailable",
			UpdatedAt: now.Format(time.RFC3339),
		}}
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	nodes, err := kubeClient.CoreV1().Nodes().List(ctx, metav1.ListOptions{})
	if err != nil {
		log.Printf("Cannot list Kubernetes nodes: %v", err)
		return []models.NodeStatus{{
			Name:      "Kubernetes API",
			Status:    "NotReady",
			Role:      "control-plane",
			Uptime:    "API unavailable",
			UpdatedAt: now.Format(time.RFC3339),
		}}
	}

	podCount := make(map[string]int)
	pods, err := kubeClient.CoreV1().Pods("").List(ctx, metav1.ListOptions{})
	if err != nil {
		log.Printf("Cannot list Kubernetes pods: %v", err)
	} else {
		for _, pod := range pods.Items {
			if pod.Spec.NodeName != "" && pod.Status.Phase != corev1.PodSucceeded && pod.Status.Phase != corev1.PodFailed {
				podCount[pod.Spec.NodeName]++
			}
		}
	}

	nodeUsage := make(map[string]corev1.ResourceList)
	if metricsClient != nil {
		metrics, err := metricsClient.MetricsV1beta1().NodeMetricses().List(ctx, metav1.ListOptions{})
		if err != nil {
			log.Printf("Cannot read Kubernetes node metrics: %v", err)
		} else {
			for _, metric := range metrics.Items {
				nodeUsage[metric.Name] = metric.Usage
			}
		}
	}

	result := make([]models.NodeStatus, 0, len(nodes.Items))

	for _, node := range nodes.Items {
		status := "NotReady"
		for _, condition := range node.Status.Conditions {
			if condition.Type == corev1.NodeReady && condition.Status == corev1.ConditionTrue {
				status = "Ready"
				break
			}
		}

		role := "worker"
		if _, exists := node.Labels["node-role.kubernetes.io/control-plane"]; exists {
			role = "control-plane"
		}

		cpu := 0.0
		ram := 0.0

		if usage, exists := nodeUsage[node.Name]; exists {
			cpu = percentage(usage.Cpu().MilliValue(), node.Status.Capacity.Cpu().MilliValue())
			ram = percentage(usage.Memory().Value(), node.Status.Capacity.Memory().Value())
		}

		result = append(result, models.NodeStatus{
			Name:      node.Name,
			Status:    status,
			Role:      role,
			CPU:       cpu,
			RAM:       ram,
			Pods:      podCount[node.Name],
			Uptime:    formatUptime(node.CreationTimestamp.Time),
			UpdatedAt: now.Format(time.RFC3339),
		})
	}

	sort.Slice(result, func(i, j int) bool {
		if result[i].Role == result[j].Role {
			return result[i].Name < result[j].Name
		}
		return result[i].Role == "control-plane"
	})

	return result
}

func getServicesStatus() []models.ServiceStatus {
	probes := []serviceProbe{
		{name: "Yandex ALB", url: envOrDefault("ALB_URL", "http://51.250.75.1/")},
		{name: "Grafana", url: envOrDefault("GRAFANA_URL", "http://51.250.75.1/grafana/login")},
		{name: "GitLab", url: envOrDefault("GITLAB_URL", "http://172.16.1.100/gitlab/users/sign_in")},
		{name: "Prometheus", url: envOrDefault("PROMETHEUS_URL", "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090/-/ready")},
	}

	result := make([]models.ServiceStatus, len(probes))
	var waitGroup sync.WaitGroup

	for index, probe := range probes {
		waitGroup.Add(1)
		go func(index int, probe serviceProbe) {
			defer waitGroup.Done()
			result[index] = checkService(probe)
		}(index, probe)
	}

	waitGroup.Wait()
	return result
}

func checkService(probe serviceProbe) models.ServiceStatus {
	client := &http.Client{
		Timeout: 3 * time.Second,
		CheckRedirect: func(_ *http.Request, _ []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}

	response, err := client.Get(probe.url)
	if err != nil {
		return models.ServiceStatus{
			Name:    probe.name,
			Status:  "error",
			URL:     probe.url,
			Message: err.Error(),
		}
	}
	defer response.Body.Close()

	status := "error"
	if response.StatusCode >= 200 && response.StatusCode < 400 {
		status = "ok"
	} else if response.StatusCode >= 400 && response.StatusCode < 500 {
		status = "degraded"
	}

	return models.ServiceStatus{
		Name:    probe.name,
		Status:  status,
		URL:     probe.url,
		Message: fmt.Sprintf("HTTP %d", response.StatusCode),
	}
}

func percentage(used, capacity int64) float64 {
	if used <= 0 || capacity <= 0 {
		return 0
	}

	value := float64(used) / float64(capacity) * 100
	if value > 100 {
		value = 100
	}

	return float64(int(value*10+0.5)) / 10
}

func formatUptime(created time.Time) string {
	duration := time.Since(created)
	if duration < 0 {
		return "0h"
	}

	days := int(duration.Hours()) / 24
	hours := int(duration.Hours()) % 24
	return fmt.Sprintf("%dd %dh", days, hours)
}

func envOrDefault(name, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(name)); value != "" {
		return value
	}
	return fallback
}
