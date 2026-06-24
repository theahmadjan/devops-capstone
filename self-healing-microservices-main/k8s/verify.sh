#!/bin/bash
# verify.sh — run AFTER deploy-all.sh to prove self-healing works today,
# not during tomorrow's live demo.

echo "### 1. Pod status (all Running, low/zero RESTARTS) ###"
kubectl get pods -n production -o wide

echo ""
echo "### 2. Probe config sanity check ###"
kubectl describe deployment flask-api -n production | grep -A 5 "Liveness\|Readiness"

echo ""
echo "### 3. THE SELF-HEALING TEST ###"
API_POD=$(kubectl get pods -n production -l app=flask-api -o jsonpath='{.items[0].metadata.name}')
echo "Killing pod: $API_POD"
kubectl delete pod "$API_POD" -n production
echo "Watching replacement spin up (Ctrl+C once a new pod shows Running):"
kubectl get pods -n production -l app=flask-api -w
