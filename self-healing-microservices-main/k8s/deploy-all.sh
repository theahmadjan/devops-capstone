#!/bin/bash
# deploy-all.sh — run from inside the repo's k8s/ folder after copying
# these manifest files in. Pauses at each step so you can verify before
# continuing — don't skip the pauses.
set -e

pause() {
  echo ""
  echo "----- $1 -----"
  read -p "Press Enter once you've confirmed the output above looks correct... "
}

echo "### STEP 1: Tool check ###"
minikube version
kubectl version --client
helm version
pause "All three should print a version with no errors"

echo "### STEP 2: Start cluster ###"
minikube start --cpus=4 --memory=6g
minikube addons enable ingress
minikube addons enable metrics-server
kubectl get nodes
pause "Node STATUS should be Ready"

echo "### STEP 3: Namespaces ###"
kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl get namespaces
pause "production and monitoring should both be listed"

echo "### STEP 4: Build images (run from repo ROOT, not k8s/) ###"
echo "cd .. && docker build -t flask-api:latest ./api"
echo "cd .. && docker build -t worker:latest ./worker"
echo "NOTE: frontend image is BLOCKED — frontend/Dockerfile doesn't exist yet."
echo "Skip frontend.yaml below until Person A finishes it."
pause "Confirm flask-api:latest and worker:latest both built via: docker images"

echo "### STEP 5: Load images into Minikube ###"
minikube image load flask-api:latest
minikube image load worker:latest
minikube image ls | grep -E 'flask-api|worker'
pause "Both images should appear above"

echo "### STEP 6: Secrets and config first ###"
kubectl apply -f mongo-secret.yaml
kubectl apply -f app-config.yaml
kubectl get secrets -n production
kubectl get configmaps -n production
pause "mongo-credentials and flask-config should be listed"

echo "### STEP 7: Core workloads (mongo, api, worker only — frontend deferred) ###"
kubectl apply -f mongo.yaml
kubectl apply -f api.yaml
kubectl apply -f worker.yaml
echo "Waiting 15s for pods to schedule..."
sleep 15
kubectl get pods -n production
pause "mongo, flask-api (x2), and worker pods should all show Running. If not: kubectl describe pod <name> -n production  /  kubectl logs <name> -n production"

echo "### STEP 8: HPA ###"
kubectl autoscale deployment flask-api --cpu-percent=50 --min=2 --max=6 -n production
kubectl get hpa -n production
pause "HPA listed. TARGETS may say <unknown> for ~1 min — normal, recheck shortly."

echo "### STEP 9: Direct pod test (bypassing ingress/frontend for now) ###"
API_POD=$(kubectl get pods -n production -l app=flask-api -o jsonpath='{.items[0].metadata.name}')
echo "Testing health endpoint inside pod: $API_POD"
kubectl exec -n production "$API_POD" -- python3 -c "import urllib.request; print(urllib.request.urlopen('http://localhost:5000/health').read())"
pause "Should print: {\"status\": \"ok\"}"

echo "### DONE (core infra). Ingress + frontend.yaml come once Person A's frontend container exists. ###"
kubectl get pods,svc,hpa -n production
