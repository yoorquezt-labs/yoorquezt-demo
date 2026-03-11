.PHONY: up down demo demo-full status logs clean \
       testnet-up testnet-down testnet-demo testnet-logs testnet-status \
       minikube-start minikube-deploy minikube-demo minikube-dash minikube-status minikube-clean \
       pull

# ─── Docker Compose ─────────────────────────────────────

## Start the full stack
up:
	docker compose up -d
	@echo ""
	@echo "Stack starting..."
	@echo "  Mesh API:     http://localhost:8080"
	@echo "  MEV Engine:   http://localhost:9090"
	@echo "  Gateway (WS): ws://localhost:9099"
	@echo "  OFA Proxy:    http://localhost:9100"
	@echo "  Grafana:      http://localhost:3000 (admin/yoorquezt)"
	@echo "  Prometheus:   http://localhost:9091"
	@echo ""
	@echo "Run 'make demo' for a 60-second walkthrough"

## Stop the stack
down:
	docker compose down

## Pull latest images
pull:
	docker compose pull

## Run 60-second demo
demo:
	@./scripts/demo-quick.sh

## Run 5-minute comprehensive demo
demo-full:
	@./scripts/demo-full.sh

## Show service status
status:
	@docker compose ps
	@echo ""
	@echo "Health checks:"
	@curl -sf http://localhost:8080/health 2>/dev/null && echo "  Mesh Node 1:  OK" || echo "  Mesh Node 1:  DOWN"
	@curl -sf http://localhost:8081/health 2>/dev/null && echo "  Mesh Node 2:  OK" || echo "  Mesh Node 2:  DOWN"
	@curl -sf http://localhost:8082/health 2>/dev/null && echo "  Mesh Node 3:  OK" || echo "  Mesh Node 3:  DOWN"
	@curl -sf http://localhost:9090/health 2>/dev/null && echo "  MEV Engine:   OK" || echo "  MEV Engine:   DOWN"
	@curl -sf http://localhost:9099/health 2>/dev/null && echo "  Gateway:      OK" || echo "  Gateway:      DOWN"

## Tail logs
logs:
	docker compose logs -f

## Clean up everything
clean:
	docker compose down -v --remove-orphans

# ─── Testnet (Real Sepolia) ──────────────────────────────

## Start stack against Sepolia testnet
testnet-up:
	@test -f .env.testnet || (echo "ERROR: .env.testnet not found. Copy .env.example to .env.testnet and fill in values." && exit 1)
	docker compose -f docker-compose.testnet.yaml --env-file .env.testnet up -d
	@echo ""
	@echo "Testnet stack starting (Sepolia)..."
	@echo "  Mesh API:     http://localhost:8080"
	@echo "  MEV Engine:   http://localhost:9090"
	@echo "  Gateway (WS): ws://localhost:9099"
	@echo "  OFA Proxy:    http://localhost:9100"
	@echo "  Grafana:      http://localhost:3000 (admin/yoorquezt)"
	@echo ""
	@echo "Run 'make testnet-demo' for the demo walkthrough"

## Stop testnet stack
testnet-down:
	docker compose -f docker-compose.testnet.yaml down

## Run demo against testnet
testnet-demo:
	@./scripts/demo-quick.sh

## Tail testnet logs
testnet-logs:
	docker compose -f docker-compose.testnet.yaml logs -f

## Testnet service health
testnet-status:
	@docker compose -f docker-compose.testnet.yaml ps
	@echo ""
	@echo "Health checks:"
	@curl -sf http://localhost:8080/health 2>/dev/null && echo "  Mesh Node 1:  OK" || echo "  Mesh Node 1:  DOWN"
	@curl -sf http://localhost:8081/health 2>/dev/null && echo "  Mesh Node 2:  OK" || echo "  Mesh Node 2:  DOWN"
	@curl -sf http://localhost:8082/health 2>/dev/null && echo "  Mesh Node 3:  OK" || echo "  Mesh Node 3:  DOWN"
	@curl -sf http://localhost:9090/health 2>/dev/null && echo "  MEV Engine:   OK" || echo "  MEV Engine:   DOWN"
	@curl -sf http://localhost:9099/health 2>/dev/null && echo "  Gateway:      OK" || echo "  Gateway:      DOWN"
	@curl -sf http://localhost:9100/healthz 2>/dev/null && echo "  OFA Proxy:    OK" || echo "  OFA Proxy:    DOWN"

# ─── Minikube ────────────────────────────────────────────

## Start minikube cluster
minikube-start:
	minikube start --cpus=4 --memory=8192 --driver=docker --profile=yoorquezt-demo
	minikube addons enable metrics-server --profile=yoorquezt-demo
	minikube addons enable ingress --profile=yoorquezt-demo
	@echo "Minikube cluster ready"

## Deploy all services to minikube
minikube-deploy:
	kubectl apply -f deploy/minikube/namespace.yaml
	kubectl apply -f deploy/minikube/
	@echo ""
	@echo "Waiting for pods..."
	kubectl -n yoorquezt-demo wait --for=condition=ready pod --all --timeout=120s
	@echo ""
	@make minikube-status

## Show minikube service status
minikube-status:
	@echo "=== Pods ==="
	kubectl -n yoorquezt-demo get pods -o wide
	@echo ""
	@echo "=== Services ==="
	kubectl -n yoorquezt-demo get svc
	@echo ""
	@echo "=== Access URLs ==="
	@echo "  Mesh API:   $$(minikube service mesh-api -n yoorquezt-demo --url --profile=yoorquezt-demo 2>/dev/null)"
	@echo "  MEV Engine: $$(minikube service mev-engine -n yoorquezt-demo --url --profile=yoorquezt-demo 2>/dev/null)"
	@echo "  Gateway:    $$(minikube service gateway -n yoorquezt-demo --url --profile=yoorquezt-demo 2>/dev/null)"
	@echo "  Grafana:    $$(minikube service grafana -n yoorquezt-demo --url --profile=yoorquezt-demo 2>/dev/null)"

## Run demo against minikube
minikube-demo:
	@MESH_URL=$$(minikube service mesh-api -n yoorquezt-demo --url --profile=yoorquezt-demo 2>/dev/null) \
	 MEV_URL=$$(minikube service mev-engine -n yoorquezt-demo --url --profile=yoorquezt-demo 2>/dev/null) \
	 GATEWAY_URL=$$(minikube service gateway -n yoorquezt-demo --url --profile=yoorquezt-demo 2>/dev/null) \
	 ./scripts/demo-quick.sh

## Open Grafana dashboard
minikube-dash:
	minikube service grafana -n yoorquezt-demo --profile=yoorquezt-demo

## Clean up minikube
minikube-clean:
	kubectl delete namespace yoorquezt-demo --ignore-not-found
	minikube delete --profile=yoorquezt-demo
