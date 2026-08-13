#!/usr/bin/env bash
set -uo pipefail

MASTER_HOST="k8s-master-ru-central1-a"

echo "=== NODES ==="
ssh "${MASTER_HOST}" \
    "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes -o wide"

echo
echo "=== PODS ==="
ssh "${MASTER_HOST}" \
    "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods --all-namespaces -o wide"

echo
echo "=== CLUSTER INFO ==="
ssh "${MASTER_HOST}" \
    "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf cluster-info"
