# Kubernetes Configs

## Назначение
Конфигурации кластера Kubernetes: namespaces, RBAC, ingress-контроллер.

## Состав
- `namespaces/` — пространства имён
- `rbac/` — роли и привязки
- `ingress/` — ingress-правила

## Применение
```bash
kubectl apply -f namespaces/
kubectl apply -f rbac/
kubectl apply -f ingress/
