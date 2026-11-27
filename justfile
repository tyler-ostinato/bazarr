# bazarr — local dev recipes
# Usage: just <recipe>
# Run from ~/development/bazarr/

cluster       := env("CLUSTER", "kind")
registry_port := env("REGISTRY_PORT", "5001")
namespace     := "bazarr"

# Show available recipes
default:
    @just --list

# Build, push to local registry, and apply manifests
deploy:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! docker ps --filter "name=kind-registry" --format "{{{{.Names}}" | grep -q "kind-registry"; then
        echo "✗ Local registry is not running. Run 'just start' from the kubernetes directory." >&2; exit 1
    fi
    echo "=> Building bazarr image..."
    docker build -t localhost:{{registry_port}}/bazarr:dev .
    echo "=> Pushing to local registry..."
    docker push localhost:{{registry_port}}/bazarr:dev
    echo "=> Applying manifests..."
    kubectl apply -f k8s/ --context "kind-{{cluster}}"
    echo "✓ bazarr deployed."

# Restart the bazarr pod
restart:
    kubectl rollout restart deployment/bazarr \
        -n "{{namespace}}" --context "kind-{{cluster}}"
    kubectl rollout status deployment/bazarr \
        -n "{{namespace}}" --context "kind-{{cluster}}"
    echo "✓ bazarr restarted."

# Stream logs
logs:
    kubectl logs -n "{{namespace}}" --context "kind-{{cluster}}" \
        --all-containers --prefix --follow \
        -l app=bazarr

# Port-forward to the Bazarr WebUI (runs in background)
forward:
    #!/usr/bin/env bash
    set -euo pipefail
    POD=$(kubectl get pod -n "{{namespace}}" --context "kind-{{cluster}}" \
        -l app=bazarr -o jsonpath='{.items[0].metadata.name}')
    if [ -z "$POD" ]; then
        echo "✗ No running bazarr pod found." >&2; exit 1
    fi
    kubectl port-forward -n "{{namespace}}" --context "kind-{{cluster}}" \
        "pod/$POD" 6767:6767 >/tmp/bazarr-forward.log 2>&1 &
    echo $! > /tmp/bazarr-forward.pid
    echo "✓ Port-forward running in background (PID $(cat /tmp/bazarr-forward.pid))"
    echo "  Open:  http://localhost:6767"
    echo "  Stop:  just forward-stop"
    echo "  Logs:  tail /tmp/bazarr-forward.log"

# Stop the background port-forward
forward-stop:
    #!/usr/bin/env bash
    if [ ! -f /tmp/bazarr-forward.pid ]; then
        echo "No port-forward PID file found — nothing to stop." >&2; exit 1
    fi
    kill "$(cat /tmp/bazarr-forward.pid)" 2>/dev/null \
        && echo "✓ Port-forward stopped." \
        || echo "Process already stopped."
    rm /tmp/bazarr-forward.pid

# Remove all bazarr resources from the cluster
teardown:
    kubectl delete -f k8s/ --context "kind-{{cluster}}" --ignore-not-found
    echo "✓ bazarr removed from cluster."
