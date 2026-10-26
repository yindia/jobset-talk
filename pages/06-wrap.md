---
layout: section
class: section
---

<div class="section-num">06</div>

# Wrapping up

<p class="lede">A debugging playbook, what else is in the box, and when to reach for JobSet.</p>

---

<div class="eyebrow"><b>Troubleshooting</b> · a playbook</div>

# When it doesn't work: look in this order

<div class="grid grid-cols-[1fr_1.2fr] gap-8 mt-2">
<div>

```bash
# 1. The JobSet's own story
kubectl describe jobset <name>     # Conditions + Events

# 2. What it created
kubectl get jobs,pods,svc \
  -l jobset.sigs.k8s.io/jobset-name=<name>

# 3. One role at a time
kubectl logs --prefix \
  -l jobset.sigs.k8s.io/replicatedjob-name=workers

# 4. The controller's view
kubectl -n jobset-system logs \
  deploy/jobset-controller-manager --tail=50
```

</div>
<div class="text-[0.7rem]">

| Symptom | Likely cause |
|---|---|
| `field is immutable` on apply | spec can't change → delete, re-apply |
| `failed calling webhook` | controller not Ready yet → wait for rollout |
| `RESTARTS` keeps climbing | a failure-policy rule matches → check `describe` events |
| Workers crash: connection refused | leader not up → `InOrder` / `dependsOn` |
| Peer name doesn't resolve | `enableDNSHostnames`, `publishNotReadyAddresses`, wrong subdomain |
| Pods `Pending` forever | exclusive placement / topology label missing, or gang can't fit |
| JobSet stuck `SUSPENDED true` | Kueue hasn't admitted it → `kubectl get workloads` |

</div>
</div>

<!--
Ninety percent of issues show up in describe's Conditions and Events. Start there every time.
-->

---

<div class="eyebrow"><b>Decision guide</b></div>

# Job or JobSet?

<div class="versus mt-4">
<div>

### Stay with a plain **Job** when…

- All pods are **identical** and independent
- Pods don't need to **talk to each other**
- A failed pod can simply be **retried alone**
- e.g. batch transforms, rendering frames, embarrassingly parallel sweeps

</div>
<div>

### Reach for **JobSet** when…

- There are **multiple roles** (leader / workers / PS / launcher)
- Pods need **stable names** to find each other
- The group must **start, fail and finish together**
- You want **ordering**, **gang admission** or **Kueue** for the whole group
- e.g. distributed training, MPI/HPC, multi-host inference warm-up, simulations

</div>
</div>

<div class="callout mt-6" v-click>

Building a platform? **Kubeflow Trainer v2** gives data scientists a higher-level `TrainJob`, and it runs on JobSet underneath.

</div>

<!--
JobSet is not a replacement for Job. It's a layer on top for when one template isn't enough.
-->

---

<div class="eyebrow"><b>Also in the box</b> · features we skipped today</div>

# More JobSet features, one line each

| Feature | What it gives you | Status |
|---|---|---|
| `ttlSecondsAfterFinished` | delete the JobSet N seconds after it finishes | stable |
| `activeDeadlineSeconds` | fail if active too long; paused while suspended | <span class="chip alpha">alpha</span> |
| `volumeClaimPolicies` | JobSet-owned PVCs, `Retain` checkpoints or `Delete` scratch | stable |
| exclusive placement | annotation: one Job per rack / zone / node pool | <span class="chip alpha">alpha</span> |
| `schedulingConstraints.topology` | keep a gang inside one topology domain (our nodes have `rack`) | <span class="chip alpha">alpha</span> |
| shared DRA `resourceClaims` | one device claim shared by a whole Job's PodGroup | <span class="chip alpha">alpha</span> |
| in-place restart | restart healthy pods without rescheduling them | <span class="chip alpha">alpha</span> |
| Kueue | quotas, queues, priorities, preemption across teams | integration |

<div class="callout mt-4 text-sm">

Every one has a runnable lesson in the JobSet repo's `tutorial/` directory and docs at **jobset.sigs.k8s.io**.

</div>

<!--
Keep this slide quick. It's here so people know these exist. Point at the tutorial for hands-on.
The demo cluster labels worker nodes with rack=rack-a/rack-b, so topology constraints can be tried on it after the talk.
-->

---

<div class="eyebrow"><b>Recap</b></div>

# Key takeaways

<div class="needs mt-6">
<div class="need" v-click>
  <span class="n">1</span>
  <h4>A group of Jobs = one workload</h4>
  <p><code>replicatedJobs</code> model roles. Each is a plain Job template × <code>replicas</code>.</p>
</div>
<div class="need" v-click>
  <span class="n">2</span>
  <h4>Stable identity for free</h4>
  <p>Headless Service + per-pod DNS + a coordinator label every pod can read.</p>
</div>
<div class="need" v-click>
  <span class="n">3</span>
  <h4>Lifecycle as a unit</h4>
  <p><code>successPolicy</code> picks what "done" means. <code>failurePolicy</code> picks the blast radius and who pays.</p>
</div>
<div class="need" v-click>
  <span class="n">4</span>
  <h4>Coordination without sleep loops</h4>
  <p><code>InOrder</code> or <code>dependsOn</code> (Ready / Complete).</p>
</div>
<div class="need" v-click>
  <span class="n">5</span>
  <h4>All-or-nothing placement</h4>
  <p><code>spec.scheduling</code> → Workload → PodGroups: no idle, deadlocked partial jobs. Kueue for quotas.</p>
</div>
<div class="need" v-click>
  <span class="n">6</span>
  <h4>Elastic, and still a gang</h4>
  <p>Scale <code>parallelism</code> in place, and the gang's <code>minCount</code> follows.</p>
</div>
</div>

---
layout: center
class: cover
---

<div class="text-center">

<div class="cover-kicker">Thank you · Questions?</div>

<h1 class="cover-title">Try it in 5 minutes</h1>

```bash
cd demo && ./cluster.sh up && ./notebook.sh
```

<div class="grid grid-cols-3 gap-8 mt-10 text-sm text-left">
<div>

### Docs
jobset.sigs.k8s.io

</div>
<div>

### Code
github.com/kubernetes-sigs/jobset

</div>
<div>

### Community
Kubernetes Slack `#wg-batch`

</div>
</div>

<div class="cover-meta mt-10">@evalsocket</div>

</div>

<!--
Leave this up during Q&A. Common questions:
- JobSet vs LeaderWorkerSet? LWS targets long-running inference serving groups. JobSet targets run-to-completion batch.
- JobSet vs MPIJob/PyTorchJob? Kubeflow Trainer v2 consolidates them on top of JobSet.
- Does it need a custom scheduler? No. It works with the default scheduler. Gang semantics come from Kueue, a plugin, or WAS.
-->
