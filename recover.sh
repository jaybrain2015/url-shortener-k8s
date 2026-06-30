#!/usr/bin/env bash
#
# recover.sh — Disaster Recovery automation for the URL shortener
#
# Assumes: `terraform apply` has already created a fresh server.
# This script does everything AFTER that: installs k3s, wires up
# kubectl, recreates secrets, and deploys the app — turning a bare
# server into the fully running system with one command.
#
# Usage:
#   export GHCR_PAT="your_github_read_packages_token"
#   ./recover.sh
#
# ---------------------------------------------------------------

set -euo pipefail   # safety: stop on any error, undefined var, or failed pipe

# --- 0. Config -------------------------------------------------
# Where your terraform lives and where kubeconfig should land.
TERRAFORM_DIR="$HOME/url-shortener/terraform"
K8S_DIR="$HOME/url-shortener/k8s"
KUBECONFIG_PATH="$HOME/k3s-cloud.yaml"
GHCR_USER="jaybrain2015"

# The PAT must be supplied via environment variable (never hardcode secrets).
: "${GHCR_PAT:?Set GHCR_PAT to your GitHub read:packages token before running}"

# --- 1. Get the server IP from Terraform -----------------------
# terraform output prints the value we defined in outputs.tf.
echo "==> Reading server IP from Terraform..."
cd "$TERRAFORM_DIR"
SERVER_IP="$(terraform output -raw server_ip)"
echo "    Server IP: $SERVER_IP"

# --- 2. Clear any stale SSH host key ---------------------------
# A rebuilt server reuses/changes its host key; clear the old one
# so SSH doesn't refuse to connect.
echo "==> Clearing old SSH host key for $SERVER_IP..."
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$SERVER_IP" >/dev/null 2>&1 || true

# --- 3. Install k3s on the server (over SSH) -------------------
# -o StrictHostKeyChecking=accept-new auto-accepts the new host key
# so the script doesn't hang on the yes/no prompt.
echo "==> Installing k3s on the server (this takes ~30-60s)..."
ssh -o StrictHostKeyChecking=accept-new "root@$SERVER_IP" \
    "curl -sfL https://get.k3s.io | sh -"

# --- 4. Pull the kubeconfig back to the laptop -----------------
echo "==> Fetching kubeconfig from the server..."
scp -o StrictHostKeyChecking=accept-new \
    "root@$SERVER_IP:/etc/rancher/k3s/k3s.yaml" "$KUBECONFIG_PATH"

# The kubeconfig says 127.0.0.1 (correct on the server, useless here).
# Replace it with the real public IP so our laptop can reach the cluster.
echo "==> Rewriting kubeconfig to point at $SERVER_IP..."
sed -i "s|127.0.0.1|$SERVER_IP|g" "$KUBECONFIG_PATH"

export KUBECONFIG="$KUBECONFIG_PATH"

# --- 5. Wait for the cluster to be ready -----------------------
echo "==> Waiting for the node to become Ready..."
until kubectl get nodes 2>/dev/null | grep -q " Ready "; do
    sleep 3
    echo "    ...still waiting for the API server"
done
echo "    Node is Ready."

# --- 6. Recreate the ghcr image-pull secret --------------------
# The cluster is brand new, so it has no credentials to pull the
# private image. Recreate the secret from the PAT.
echo "==> Creating ghcr-secret for private image pulls..."
kubectl create secret docker-registry ghcr-secret \
    --docker-server=ghcr.io \
    --docker-username="$GHCR_USER" \
    --docker-password="$GHCR_PAT" \
    --dry-run=client -o yaml | kubectl apply -f -

# --- 7. Deploy the application ---------------------------------
echo "==> Deploying app, database, redis, and servicemonitor..."
kubectl apply -f "$K8S_DIR/redis.yaml"
kubectl apply -f "$K8S_DIR/db.yaml"
kubectl apply -f "$K8S_DIR/app.yaml"
kubectl apply -f "$K8S_DIR/servicemonitor.yaml" || true  # ok if CRD not ready yet

# --- 8. Wait for the app to be ready and verify ----------------
echo "==> Waiting for app pods to be Running..."
kubectl rollout status deployment/app --timeout=120s

echo "==> Verifying the app responds..."
sleep 5
if curl -fsS -m 10 "http://$SERVER_IP:30080/" >/dev/null; then
    echo "RECOVERY COMPLETE — app is live at http://$SERVER_IP:30080/"
else
    echo "App deployed but health check failed; check 'kubectl get pods'."
fi