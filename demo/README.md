# Live demo

Everything the talk runs, in the order the slides show it.

```bash
./cluster.sh up                  # create/reuse the cluster (first run builds the node image)
./notebook.sh                    # JupyterLab via uvx, nothing to install
```

## The cluster (`cluster.sh`)

One kind cluster runs every demo, gang scheduling included:

- Kubernetes `v1.37.0` with Workload-Aware Scheduling: feature gate `GenericWorkload`
  and `--runtime-config=scheduling.k8s.io/v1beta1=true` (plus the topology and DRA gates)
- 1 control plane + 3 workers, labelled `rack=rack-a|rack-b`
- each worker advertises 2 fake GPUs (`example.com/gpu`), so gang demos are
  predictable on any laptop
- JobSet `v0.13.0` with `JobSetWorkloadAwareSchedulingAPI`, `ElasticJobSet`,
  `RestartJob`, `JobSetActiveDeadlineSeconds` and `ExecutionAttemptsTracking` on

Override with env vars: `CLUSTER`, `K8S_VERSION`, `JOBSET_VERSION`, `NODE_IMAGE`, `FAKE_GPUS`.
Subcommands: `up`, `status`, `reset` (delete all JobSets/Jobs), `down`.

## Manifests

| File | NB steps | Features in one example |
|------|----------|-------------------------|
| `00-plain-job.yaml` | 1.1 | A plain indexed Job, for contrast |
| `01-hello.yaml` | 2.1 – 3.1 | Roles, naming, labels, headless Service + DNS, coordinator, success policy, webhook defaults |
| `02-resilient.yaml` | 3.2 – 3.5 | Failure policy: `RestartJob`, `RestartJobSet`, `...IgnoreMaxRestarts` via `podFailurePolicy`, `maxRestarts` |
| `03-pipeline.yaml` | 4.1 | `dependsOn` (Complete → Ready) |
| `04-train.yaml` | 5.1, 5.2, 5.6 | Gang per role, Workload / PodGroupTemplate / PodGroup, `disruptionMode`, suspend/resume |
| `05-big-no-gang.yaml` | 5.3 | Baseline: partial placement without gang scheduling |
| `05-big.yaml` | 5.4, 5.5 | All-or-nothing gang, then ElasticJobSet scale-down with `minCount` patched in place |

Section 5 depends on order: `train` holds 4 of the 6 GPUs while the `big` demos run.

## Notebook

Every cell is plain shell (`%%bash` on the first line): `kubectl`, `cat`, `sleep` and a
little `jq`. Each demo step starts with `cat manifests/<file>.yaml`, and the generated
objects are shown with `kubectl get ... -o yaml`. Cells run in order and don't share
variables, so you can re-run any cell on its own.

Requirements: `kind` ≥ 0.32 (Kubernetes 1.37 needs kubeadm `v1beta4` configs) and
`kubectl` ≥ 1.36. `brew upgrade kind kubectl` gets both. Optional: `kubectl krew install tree`.
