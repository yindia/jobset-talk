---
layout: section
class: section
---

<div class="section-num">05</div>

# Gang scheduling: all or nothing

<p class="lede">Need #3: a distributed job with 7 of its 8 pods running is worse than no job at all. Then: elastic scaling, with the gang following along.</p>

---

<div class="eyebrow"><b>The problem</b> · partial placement</div>

# The default scheduler places pods one at a time

<div class="grid grid-cols-[1.2fr_1fr] gap-8 mt-4">
<div>

<p class="text-xs mb-2 font-mono opacity-70">Cluster: 3 nodes × 2 GPU slots · Job <b style="color:var(--k8s)">A</b> needs 4 pods · Job <b style="color:var(--wait)">B</b> needs 4 pods</p>

<div class="nodes">
  <div class="node"><div class="node-name">node-1</div><div class="slots"><div class="slot a stuck">A0</div><div class="slot b stuck">B0</div></div></div>
  <div class="node"><div class="node-name">node-2</div><div class="slots"><div class="slot a stuck">A1</div><div class="slot b stuck">B1</div></div></div>
  <div class="node"><div class="node-name">node-3</div><div class="slots"><div class="slot a stuck">A2</div><div class="slot b stuck">B2</div></div></div>
</div>

<div class="flex gap-3 mt-3 font-mono text-[0.62rem]">
  <span class="chip wait">A3 Pending</span>
  <span class="chip wait">B3 Pending</span>
  <span class="chip fail">6 GPUs held · 0 useful work</span>
</div>

</div>
<div class="text-sm">

<v-clicks>

- Both jobs are **3/4 placed**. Neither can start its first collective op.
- Each holds GPUs that the other needs → **deadlock**
- Even with one job, partial pods sit idle until the rest fit, **burning accelerator hours**
- Pod-by-pod scheduling simply can't see "this group of 4"

</v-clicks>

</div>
</div>

<div class="callout ok mt-6" v-click>

**Gang scheduling:** treat the group as one unit. Admit all `minCount` pods together, or admit none. Here, A gets all 4 slots and runs while B waits *without* holding anything.

</div>

<!--
This is the most important conceptual slide of the section. Draw the deadlock with your hands if you like.
-->

---

<div class="eyebrow"><b>Ecosystem</b> · where gang scheduling lives</div>

# Gang scheduling in the Kubernetes ecosystem

| Layer | Project | How it gets all-or-nothing |
|---|---|---|
| **Admission / quota** | **Kueue** | Keeps the workload `suspend`ed until quota for *all* pods is reserved, then admits it as one unit. Optional `waitForPodsReady`. |
| **Scheduler plugin** | scheduler-plugins **Coscheduling**, **Volcano** | A `PodGroup` with `minMember`: the scheduler won't bind any pod until the group fits |
| **Upstream (new)** <span class="chip alpha">beta · 1.37</span> | Kubernetes **Workload-Aware Scheduling** (WAS) | Built-in `scheduling.k8s.io` `Workload` + `PodGroup` APIs; kube-scheduler admits a gang only when `minCount` pods fit |

<div class="grid grid-cols-2 gap-6 mt-6">
<div class="callout" v-click>

**Where does JobSet fit?** JobSet *describes* the group: roles, counts, ordering. A scheduler or queue *enforces* atomic placement. JobSet integrates with Kueue today, and can generate upstream `Workload`/`PodGroup` objects (alpha).

</div>
<div class="callout" v-click>

**Kueue today:** label the JobSet `kueue.x-k8s.io/queue-name: team-a`. Kueue keeps it suspended until quota for **all** its pods is free, then admits it in one go. **WAS** moves the gang into kube-scheduler itself.

</div>
</div>

<!--
Avoid a turf war: these are complementary. Kueue answers "should this run now?". The scheduler answers "where do the pods go, all at once?".
-->

---

<div class="eyebrow"><b>Workload-Aware Scheduling</b> · the upstream building blocks</div>

# Workload, PodGroupTemplate, PodGroup: who's who

<div class="grid grid-cols-[1.25fr_1fr] gap-8 mt-2 items-start">
<div class="model">
  <div class="model-box blueprint">
    <div class="model-head"><span>Workload</span><span class="kind">scheduling.k8s.io/v1beta1</span></div>
    <div class="model-sub">the <b>blueprint</b>: what groups this workload has</div>
    <div class="model-row">
      <div class="model-tmpl"><b>podGroupTemplates[0]</b><br>schedulingPolicy: gang{minCount}<br>disruptionMode · topology · claims</div>
      <div class="model-tmpl"><b>podGroupTemplates[1]</b><br>…up to 8 templates</div>
    </div>
  </div>
  <div class="model-link">↓ one runtime instance per template · <code>spec.workloadRef{workloadName, templateName}</code></div>
  <div class="model-row">
    <div class="model-box runtime">
      <div class="model-head"><span>PodGroup</span><span class="kind">v1beta1</span></div>
      <div class="model-sub">what <b>kube-scheduler</b> admits as a unit</div>
    </div>
    <div class="model-box runtime">
      <div class="model-head"><span>PodGroup</span><span class="kind">v1beta1</span></div>
      <div class="model-sub">status: <code>PodGroupInitiallyScheduled</code></div>
    </div>
  </div>
  <div class="model-link">↓ each Pod joins by name · <code>spec.schedulingGroup.podGroupName</code></div>
  <div class="pods"><span class="pod">pod</span><span class="pod">pod</span><span class="pod">pod</span><span class="pod">pod</span><span class="pod">pod</span></div>
</div>
<div class="text-sm">

<v-clicks>

- **Workload**: the static *shape*. Which groups exist and how each one must be scheduled. Owned by the controller that created it (here, the JobSet).
- **PodGroupTemplate**: one entry inside the Workload, holding the policy: `basic` (pod by pod) or `gang` (`minCount` together), plus disruption, topology, DRA claims and priority.
- **PodGroup**: the *live* object made from a template. The scheduler binds none of its pods until `minCount` can be placed.
- **CompositePodGroup** <span class="chip alpha">alpha</span>: groups of PodGroups, for "gang of gangs". Coming next.

</v-clicks>

</div>
</div>

<!--
Analogy: Workload is like a class definition, PodGroup is an instance, Pods point at the instance by name.
The upstream design is KEP-6089 (WAS controller APIs) in kubernetes/enhancements. The JobSet side is KEP-969 in the jobset repo.
-->

---

<div class="eyebrow"><b>JobSet + WAS</b> · demo/manifests/04-train.yaml <span class="nb">▶ NB 5.1</span></div>

# Turn it on: one gang per role

<div class="grid grid-cols-[0.95fr_1.05fr] gap-6 mt-1">
<div>

```yaml {2-11|13-14|15-18}
spec:
  scheduling:
    replicatedJobs:
    - targetReplicatedJobs: [driver]
      schedulingPolicy:
        gang: {}
    - targetReplicatedJobs: [workers]
      schedulingPolicy:
        gang: {}
      disruptionMode:
        all: {}          # preempt as a unit
  replicatedJobs:
  - name: driver         # 1 × 1 pod, no GPU
    replicas: 1
  - name: workers        # 2 Jobs × 2 pods
    replicas: 2
    ...parallelism: 2
    ...limits: {example.com/gpu: 1}
```

</div>
<div>

<Term cmd="kubectl get workloads.scheduling.k8s.io,podgroups -l jobset.sigs.k8s.io/jobset-name=train">

```text
NAME                                          AGE
workload.scheduling.k8s.io/train-4f1c2a9e07   8s

NAME                                                  AGE
podgroup.scheduling.k8s.io/train-driver-a3b81c5d2e    8s
podgroup.scheduling.k8s.io/train-workers-9d02e6f471   8s
```

</Term>

<Term cmd="kubectl get podgroups -l …=train -o custom-columns=NAME:.metadata.name,TEMPLATE:.spec.workloadRef.templateName,MIN:.spec.schedulingPolicy.gang.minCount">

```text
NAME                       TEMPLATE             MIN
train-driver-a3b81c5d2e    driver-a3b81c5d2e    1
train-workers-9d02e6f471   workers-9d02e6f471   4
```

</Term>

<div class="text-xs mt-2 leading-5">

<v-clicks>

- **1** Workload → **1** template per entry (max 8) → **1** PodGroup each
- `minCount` is computed for you: `parallelism × replicas`
- Each child Job gets annotation `scheduling.k8s.io/group-template-name`, and each pod gets `spec.schedulingGroup.podGroupName`

</v-clicks>

</div>
</div>
</div>

<!--
The notebook prints the full Workload and PodGroup YAML, plus the Job annotation and the pod's schedulingGroup.
Use workloads.scheduling.k8s.io explicitly: Kueue also has a resource called "workloads".
train keeps running and holds 4 of the 6 fake GPUs for the next demos.
-->

---

<div class="eyebrow"><b>Two trees</b> · demo/manifests/04-train.yaml <span class="nb">▶ NB 5.2</span></div>

# Who owns it vs. who gets scheduled together

<div class="grid grid-cols-2 gap-8 mt-2 items-start">
<div>

### Ownership · deleted with the JobSet

<ul class="otree compact">
  <li><span class="tnode jobset"><span class="k">JobSet</span> train</span>
    <ul>
      <li><span class="tnode wl"><span class="k">Workload</span> train-4f1c2a9e07</span></li>
      <li><span class="tnode pg"><span class="k">PodGroup</span> train-driver-a3b8…</span></li>
      <li><span class="tnode pg"><span class="k">PodGroup</span> train-workers-9d02…</span></li>
      <li><span class="tnode svc"><span class="k">Service</span> train</span></li>
      <li><span class="tnode"><span class="k">Job</span> train-driver-0</span>
        <ul><li><span class="tnode pod">Pod driver-0-0</span></li></ul>
      </li>
      <li><span class="tnode"><span class="k">Job</span> train-workers-0</span>
        <ul><li><span class="tnode pod">Pod workers-0-0</span></li><li><span class="tnode pod">Pod workers-0-1</span></li></ul>
      </li>
      <li><span class="tnode"><span class="k">Job</span> train-workers-1</span>
        <ul><li><span class="tnode pod">Pod workers-1-0</span></li><li><span class="tnode pod">Pod workers-1-1</span></li></ul>
      </li>
    </ul>
  </li>
</ul>

</div>
<div v-click>

### Scheduling · admitted together

<ul class="otree dashed compact">
  <li><span class="tnode wl"><span class="k">Workload</span> train-4f1c2a9e07</span>
    <ul>
      <li><span class="tnode tmpl">template driver-a3b8… · gang minCount 1</span>
        <ul><li><span class="tnode pg"><span class="k">PodGroup</span> train-driver-a3b8…</span>
          <ul><li><span class="tnode pod">Pod driver-0-0</span></li></ul>
        </li></ul>
      </li>
      <li><span class="tnode tmpl">template workers-9d02… · gang minCount 4</span>
        <ul><li><span class="tnode pg"><span class="k">PodGroup</span> train-workers-9d02…</span>
          <ul>
            <li><span class="tnode pod">Pod workers-0-0</span><span class="tnote">Job workers-0</span></li>
            <li><span class="tnode pod">Pod workers-0-1</span><span class="tnote">Job workers-0</span></li>
            <li><span class="tnode pod">Pod workers-1-0</span><span class="tnote">Job workers-1</span></li>
            <li><span class="tnode pod">Pod workers-1-1</span><span class="tnote">Job workers-1</span></li>
          </ul>
        </li></ul>
      </li>
    </ul>
  </li>
</ul>

</div>
</div>

<div class="callout ok mt-2 text-sm" v-click>

The `workers` gang **spans two Jobs**. Pods join it by `schedulingGroup.podGroupName`, not by owner, which is why JobSet builds the Workload.

</div>

<!--
Left: solid lines = ownerReferences, everything hangs off the JobSet. Right: dashed lines = scheduling references (workloadRef, podGroupName).
Same pods, two different trees. Ownership decides cleanup; the scheduling tree decides admission.
-->

---

<div class="eyebrow"><b>Gang in action</b> · train holds 4 of 6 GPUs <span class="nb">▶ NB 5.3 – 5.4</span></div>

# Only 2 GPUs left, and a job that needs 4

<div class="grid grid-cols-2 gap-6 mt-1">
<div>

### Without gang · 05-big-no-gang.yaml

<Term cmd="kubectl get pods -l jobset.sigs.k8s.io/replicatedjob-name=workers,jobset.sigs.k8s.io/jobset-name=big-no-gang">

```text {2-3|4-5}
NAME                            READY   STATUS    AGE
big-no-gang-workers-0-0-a7d3q   1/1     Running   20s
big-no-gang-workers-0-1-p9c2w   1/1     Running   20s
big-no-gang-workers-1-0-h4n8e   0/1     Pending   20s
big-no-gang-workers-1-1-t6v1r   0/1     Pending   20s
```

</Term>

<div class="callout fail mt-2 text-xs">

**Partial placement:** 2 workers grab the last 2 GPUs and still can't make progress.

</div>

</div>
<div v-click>

### With per-role gangs · 05-big.yaml

<Term cmd="kubectl get pods -l jobset.sigs.k8s.io/replicatedjob-name=workers,jobset.sigs.k8s.io/jobset-name=big">

```text
NAME                    READY   STATUS    AGE
big-workers-0-0-k2m9x   0/1     Pending   20s
big-workers-0-1-r8s1d   0/1     Pending   20s
big-workers-1-0-w5e2a   0/1     Pending   20s
big-workers-1-1-c0v7n   0/1     Pending   20s
```

</Term>

<Term cmd="kubectl get podgroups -l …=big -o custom-columns=NAME:.metadata.name,MIN:.spec.schedulingPolicy.gang.minCount,SCHEDULED:.status.conditions[0].status,REASON:.status.conditions[0].reason">

```text
NAME                     MIN   SCHEDULED   REASON
big-driver-5b0e19a4c2    1     True
big-workers-c81f7e2d90   4     False       Unschedulable
```

</Term>

</div>
</div>

<div class="callout ok mt-2 text-xs" v-click>

All 4 wait **and hold nothing**: the 2 free GPUs stay free for others. The driver's own gang (min 1) still runs.

</div>

<!--
Run the baseline first and delete it, so it doesn't hold the 2 free GPUs when big is applied.
Condition names come from scheduling.k8s.io/v1beta1 (PodGroupInitiallyScheduled, reason Unschedulable). The notebook prints the real values.
-->

---

<div class="eyebrow"><b>Elastic</b> · ElasticJobSet <span class="chip alpha">alpha</span> <span class="nb">▶ NB 5.5</span></div>

# Shrink it in place, and the gang follows

<div class="grid grid-cols-[1fr_1fr] gap-6 mt-1">
<div>

<Term cmd="kubectl patch jobset big --type=json -p '[{&quot;op&quot;:&quot;replace&quot;,&quot;path&quot;:&quot;/spec/replicatedJobs/1/template/spec/parallelism&quot;,&quot;value&quot;:1},{&quot;op&quot;:&quot;replace&quot;,&quot;path&quot;:&quot;/spec/replicatedJobs/1/template/spec/completions&quot;,&quot;value&quot;:1}]'">

```text
jobset.jobset.x-k8s.io/big patched
```

</Term>

<div class="text-sm mt-4">

<v-clicks>

- With `ElasticJobSet`, `parallelism`/`completions` are the **only** spec fields you can change on a running JobSet
- The JobSet controller scales the child Jobs: **2 Jobs × 1 pod** now
- It **patches the PodGroup's `minCount` in place** (4 → 2). Nothing is deleted or recreated
- The new, smaller gang fits in the 2 free GPUs, so both workers bind **together**

</v-clicks>

</div>
</div>
<div>

<Term cmd="kubectl get podgroups -l …=big -o custom-columns=NAME:.metadata.name,MIN:.spec.schedulingPolicy.gang.minCount">

```text {3}
NAME                     MIN
big-driver-5b0e19a4c2    1
big-workers-c81f7e2d90   2
```

</Term>

<Term cmd="kubectl get pods -l jobset.sigs.k8s.io/replicatedjob-name=workers,jobset.sigs.k8s.io/jobset-name=big">

```text
NAME                    READY   STATUS    AGE
big-workers-0-0-k2m9x   1/1     Running   2m
big-workers-1-0-w5e2a   1/1     Running   2m
```

</Term>

<div class="callout mt-3 text-xs">

Leave `gang.minCount` unset for elastic jobs. An explicit value blocks scaling below it. Growing works the same way: patch `parallelism` up and `minCount` rises with it.

</div>

</div>
</div>

<!--
The patch uses JSON Patch so only two fields change. spec.scheduling is immutable, and a merge patch would have to repeat the whole replicatedJobs entry.
replicatedJobs/1 = workers (index 0 is driver).
-->

---

<div class="eyebrow"><b>Lifecycle</b> · the JobSet controller owns these objects <span class="nb">▶ NB 5.6</span></div>

# Suspend releases the gang, resume brings it back

<div class="grid grid-cols-[1fr_1.1fr] gap-7 mt-1">
<div>

<Term cmd="kubectl patch jobset train --type=merge -p '{&quot;spec&quot;:{&quot;suspend&quot;:true}}'; kubectl get workloads.scheduling.k8s.io,podgroups -l …=train">

```text
jobset.jobset.x-k8s.io/train patched
No resources found in default namespace.
```

</Term>

<Term cmd="kubectl patch jobset train --type=merge -p '{&quot;spec&quot;:{&quot;suspend&quot;:false}}'; kubectl get podgroups -l …=train">

```text
jobset.jobset.x-k8s.io/train patched
NAME                       AGE
train-driver-a3b81c5d2e    2s
train-workers-9d02e6f471   2s
```

</Term>

<div class="callout mt-3 text-xs">

Same names on resume. That's why this works well with **Kueue**, which queues a JobSet by keeping it suspended.

</div>

</div>
<div>

| JobSet event | Workload / PodGroups |
|---|---|
| Created with `spec.scheduling` | **created** before any Job |
| `suspend: true` / `false` | **deleted** / **recreated** |
| Failure-policy restart | **kept**, and new Jobs re-map |
| Elastic scale | `minCount` **patched in place** |
| Other template change | deleted and recreated |
| Completed / Failed | **deleted**, freeing the reservation |
| Gate off + `spec.scheduling` | JobSet **rejected** at admission |

<div class="text-xs mt-3 opacity-90">

Rules: pick **one** model (top-level *or* `replicatedJobs[]`, never both) · every role targeted once · `dependsOn`/`InOrder` need per-role gangs · `spec.scheduling` is immutable while running.

</div>

</div>
</div>

<!--
The controller waits for the Workload to exist before creating Jobs, so pods never point at a missing PodGroup.
-->

---

<div class="eyebrow"><b>Granularity</b> · match the gang to your dependency structure</div>

# One gang, or many?

| Shape | `spec.scheduling` | Generates |
|---|---|---|
| **Whole JobSet** | `schedulingPolicy: {gang: {}}` | 1 PodGroup `<js>-<hash>`, minCount = all pods |
| **Per role** | `replicatedJobs: [{targetReplicatedJobs: [driver]}, {… [workers]}]` | 1 PodGroup per role, `<js>-<role>-<hash>` |
| **Roles shared** | `targetReplicatedJobs: [launcher, worker]` | 1 PodGroup `<js>-launcher-worker-<hash>`, minCount = sum |
| **Gang of gangs** | `job:` inside a `replicatedJobs` entry | 1 PodGroup **per Job replica** `<js>-<role>-<idx>-<hash>` (e.g. per TPU slice) |

<div class="callout fail mt-6" v-click>

**Gotcha:** `dependsOn` / `InOrder` + one JobSet-wide gang = deadlock, because the gang waits for pods that won't be created until the leader is Ready. JobSet **rejects** that combination. Use per-role gangs instead.

</div>

<div class="callout mt-3" v-click>

Also in WAS: `schedulingConstraints.topology` (keep a gang on one rack), shared DRA `resourceClaims` per Job, and `disruptionMode: all` for whole-gang preemption.

</div>

<!--
Most people need "whole JobSet" or "per role". Gang-of-gangs is for multi-slice / multi-host accelerators where each slice is independently schedulable.
True composite hierarchies (a gang of those gangs) need CompositePodGroup: JobSet's Alpha 2 milestone with Kubernetes 1.38.
-->
