package main

import (
	"log"
	"net/http"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func startMetricsServer(port string, version string) {
	appInfo := prometheus.NewGauge(
		prometheus.GaugeOpts{
			Name: "infra_app_info",
			Help: "Information about the running infra application.",
			ConstLabels: prometheus.Labels{
				"version": version,
			},
		},
	)

	prometheus.MustRegister(appInfo)
	appInfo.Set(1)

	metricsMux := http.NewServeMux()
	metricsMux.Handle("/metrics", promhttp.Handler())

	server := &http.Server{
		Addr:              ":" + port,
		Handler:           metricsMux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Printf("Infra metrics server starting on :%s\n", port)

	if err := server.ListenAndServe(); err != nil {
		log.Fatalf("Infra metrics server stopped: %v", err)
	}
}
