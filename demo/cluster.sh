#!/usr/bin/env bash
# One kind cluster that can run every demo in the talk, gang scheduling included.
#
#   ./cluster.sh up       create the cluster and install JobSet (idempotent)
#   ./cluster.sh status   show nodes, fake GPUs, scheduling APIs, JobSet gates
#   ./cluster.sh reset    delete every JobSet/Job in the default namespace
#   ./cluster.sh down     delete the cluster
#
# What "up" builds:
#   - Kubernetes ${K8S_VERSION} with Workload-Aware Scheduling (WAS) enabled:
#     feature gate GenericWorkload + runtime-config scheduling.k8s.io/v1beta1
#   - 1 control-plane + 3 worker nodes
#   - each worker advertises ${FAKE_GPUS} fake GPUs (example.com/gpu), so gang
#     scheduling demos behave the same on every laptop
#   - JobSet ${JOBSET_VERSION} with the alpha controller gates turned on:
#     JobSetWorkloadAwareSchedulingAPI, ElasticJobSet, RestartJob,
#     JobSetActiveDeadlineSeconds, ExecutionAttemptsTracking
#
# Requires: docker, kind >= v0.32 (Kubernetes 1.37 needs kubeadm v1beta4 configs),
# kubectl >= 1.36, jq. Override any variable below via env, e.g. KIND=/path/to/kind.
set -euo pipefail

CLUSTER="${CLUSTER:-jobset-demo}"
K8S_VERSION="${K8S_VERSION:-v1.37.0}"
JOBSET_VERSION="${JOBSET_VERSION:-v0.13.0}"
NODE_IMAGE="${NODE_IMAGE:-kindest/node:${K8S_VERSION}}"
FAKE_GPUS="${FAKE_GPUS:-2}"
GPU_RESOURCE="example.com/gpu"
GPU_JSON_PATH='example.com~1gpu'  # "/" escaped for JSON Patch
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTEXT="kind-${CLUSTER}"
KIND="${KIND:-kind}"
MIN_KIND_VERSION="0.32.0"

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
k() { kubectl --context "$CONTEXT" "$@"; }

require_tools() {
  local tool
  for tool in docker "$KIND" kubectl jq; do
    command -v "$tool" >/dev/null || die "'$tool' is not installed"
  done
  docker info >/dev/null 2>&1 || die "docker is not running"

  local kind_version
  kind_version="$("$KIND" version | sed -E 's/^kind v([0-9.]+).*/\1/')"
  if ! version_at_least "$kind_version" "$MIN_KIND_VERSION"; then
    die "kind $kind_version is too old for Kubernetes ${K8S_VERSION} (needs >= v${MIN_KIND_VERSION}).
  Upgrade:  brew upgrade kind      (or: go install sigs.k8s.io/kind@v${MIN_KIND_VERSION})
  Or point at another binary:  KIND=/path/to/kind $0 up"
  fi
}

# version_at_least 0.32.1 0.32.0 -> true
version_at_least() {
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" == "$2" ]]
}

# kind publishes node images for most releases; if this one is missing,
# build it from the official Kubernetes server tarball (takes a few minutes).
ensure_node_image() {
  if docker image inspect "$NODE_IMAGE" >/dev/null 2>&1; then
    return
  fi
  log "Pulling node image $NODE_IMAGE"
  if docker pull "$NODE_IMAGE"; then
    return
  fi
  local arch
  case "$(uname -m)" in
    arm64 | aarch64) arch=arm64 ;;
    *) arch=amd64 ;;
  esac
  NODE_IMAGE="jobset-demo/node:${K8S_VERSION}"
  log "No published image; building $NODE_IMAGE from Kubernetes $K8S_VERSION ($arch)"
  "$KIND" build node-image --image "$NODE_IMAGE" \
    "https://dl.k8s.io/${K8S_VERSION}/kubernetes-server-linux-${arch}.tar.gz"
}

create_cluster() {
  if "$KIND" get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
    log "Cluster $CLUSTER already exists, reusing it"
    return
  fi
  log "Creating kind cluster $CLUSTER (1 control plane + 3 workers, WAS enabled)"
  "$KIND" create cluster --name "$CLUSTER" --image "$NODE_IMAGE" --wait 3m --config - <<'YAML'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
featureGates:
  GenericWorkload: true                  # Workload / PodGroup + gang scheduling
  TopologyAwareWorkloadScheduling: true  # schedulingConstraints.topology
  DRAWorkloadResourceClaims: true        # shared resourceClaims per PodGroup
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: ClusterConfiguration
    apiVersion: kubeadm.k8s.io/v1beta4
    apiServer:
      extraArgs:
      - name: runtime-config
        value: "scheduling.k8s.io/v1beta1=true"
- role: worker
  labels: {rack: rack-a}
- role: worker
  labels: {rack: rack-a}
- role: worker
  labels: {rack: rack-b}
YAML
}

install_jobset() {
  if k get deploy -n jobset-system jobset-controller-manager >/dev/null 2>&1; then
    log "JobSet already installed"
  else
    log "Installing JobSet $JOBSET_VERSION"
    local url="https://github.com/kubernetes-sigs/jobset/releases/download/${JOBSET_VERSION}/manifests.yaml"
    k apply --server-side -f "$url" ||
      k apply --server-side -k "github.com/kubernetes-sigs/jobset/config/default?ref=${JOBSET_VERSION}"
  fi
  k -n jobset-system rollout status deploy/jobset-controller-manager --timeout=180s

  log "Turning on JobSet controller feature gates"
  k -n jobset-system create configmap jobset-manager-config --dry-run=client -o yaml \
    --from-literal=controller_manager_config.yaml="$(cat <<'EOF'
apiVersion: config.jobset.x-k8s.io/v1alpha1
kind: Configuration
leaderElection:
  leaderElect: true
internalCertManagement:
  enable: true
featureGates:
  JobSetWorkloadAwareSchedulingAPI: true
  ElasticJobSet: true
  RestartJob: true
  JobSetActiveDeadlineSeconds: true
  ExecutionAttemptsTracking: true
EOF
)" | k apply -f -
  k -n jobset-system rollout restart deploy/jobset-controller-manager
  k -n jobset-system rollout status deploy/jobset-controller-manager --timeout=180s
  # The webhook serves with self-managed certs; give it a moment to be reachable.
  local i
  for i in $(seq 1 30); do
    if k apply --dry-run=server -f "$SCRIPT_DIR/manifests/01-hello.yaml" >/dev/null 2>&1; then
      return
    fi
    sleep 2
  done
  die "JobSet webhook did not become ready"
}

# Advertise an extended resource on each worker, the documented way:
# https://kubernetes.io/docs/tasks/administer-cluster/extended-resource-node/
add_fake_gpus() {
  log "Advertising $FAKE_GPUS x $GPU_RESOURCE on every worker"
  local node
  for node in $(k get nodes -l '!node-role.kubernetes.io/control-plane' -o name); do
    k patch "$node" --subresource=status --type=json -p "[
      {\"op\":\"add\",\"path\":\"/status/capacity/${GPU_JSON_PATH}\",\"value\":\"${FAKE_GPUS}\"},
      {\"op\":\"add\",\"path\":\"/status/allocatable/${GPU_JSON_PATH}\",\"value\":\"${FAKE_GPUS}\"}]" >/dev/null
  done
}

status() {
  k get nodes -o custom-columns='NODE:.metadata.name,RACK:.metadata.labels.rack,GPUS:.status.allocatable.example\.com/gpu'
  echo
  k api-resources --api-group=scheduling.k8s.io -o name
  echo
  k -n jobset-system get cm jobset-manager-config -o jsonpath='{.data.controller_manager_config\.yaml}' | sed -n '/featureGates/,$p'
}

reset() {
  k delete jobsets --all --wait=true
  k delete jobs --all --wait=true
}

main() {
  case "${1:-up}" in
    up)
      require_tools
      ensure_node_image
      create_cluster
      install_jobset
      add_fake_gpus
      log "Ready. Context: $CONTEXT"
      status
      ;;
    status) status ;;
    reset) reset ;;
    down) "$KIND" delete cluster --name "$CLUSTER" ;;
    *) die "usage: $0 [up|status|reset|down]" ;;
  esac
}

main "$@"
