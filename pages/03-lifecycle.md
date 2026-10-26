---
layout: section
class: section
---

<div class="section-num">03</div>

# Lifecycle: succeed and fail as a unit

<p class="lede">When is the whole thing "done"? And when one piece breaks, what restarts, and who pays for it?</p>

---

<div class="eyebrow"><b>Success policy</b> · still the hello JobSet <span class="nb">▶ NB 3.1</span></div>

# Done when the real work is done

<div class="grid grid-cols-[0.9fr_1.1fr] gap-6 mt-2">
<div>

<div class="states mb-5 text-[0.62rem]">
  <span class="state">Created</span><span class="arrow">→</span>
  <span class="state wait">Active</span><span class="arrow">⇄</span>
  <span class="state wait">Restarting</span><span class="arrow">→</span>
  <div class="flex flex-col gap-2"><span class="state ok">Completed</span><span class="state fail">Failed</span></div>
</div>

<div class="text-sm">

<v-clicks>

- **Default:** *all* Jobs complete → Completed. *Any* Job fails → Failed.
- `hello` says: complete when **`workers`** complete
- The leader runs `sleep 3600`, and JobSet **tears it down** for you
- Use it for coordinators / parameter servers that never exit, `Any` for "first finisher wins", and freeing GPUs the moment training ends

</v-clicks>

</div>
</div>
<div>

<Term cmd="kubectl wait --for=condition=Completed jobset/hello --timeout=180s">

```text
jobset.jobset.x-k8s.io/hello condition met
```

</Term>

<Term cmd="kubectl get jobset hello">

```text
NAME    TERMINALSTATE   RESTARTS   COMPLETED   SUSPENDED   AGE
hello   Completed       0          True        false       2m
```

</Term>

<Term cmd="kubectl get jobs -l jobset.sigs.k8s.io/jobset-name=hello">

```text {2,3}
NAME              STATUS     COMPLETIONS   DURATION   AGE
hello-workers-0   Complete   2/2           97s        2m
hello-workers-1   Complete   2/2           97s        2m
```

</Term>

<div class="callout ok mt-2 text-xs" v-click>

`hello-leader-0` is gone: it was deleted when the policy was met, not after its hour-long sleep.

</div>

</div>
</div>

<!--
Workers sleep ~90s in the demo, so there's time to show networking first and then come back here.
-->

---

<div class="eyebrow"><b>Failure policy</b> · demo/manifests/02-resilient.yaml</div>

# A restart budget plus ordered rules

<div class="grid grid-cols-[0.95fr_1.05fr] gap-8 mt-2">
<div>

```yaml {2|3-6|7-9|10-12}
failurePolicy:
  maxRestarts: 3             # the budget
  rules:                     # top-down, first match wins
  - name: infra-blip         # exit 42 = "preempted"
    action: RestartJobSetAndIgnoreMaxRestarts
    onJobFailureReasons: [PodFailurePolicy]
  - name: leader-down
    action: RestartJobSet
    targetReplicatedJobs: [leader]
  - name: worker-down
    action: RestartJob
    targetReplicatedJobs: [workers]
```

<div class="callout mt-3 text-xs">

Each Job has a `podFailurePolicy`: exit code **42 → FailJob**, so the Job fails with reason **`PodFailurePolicy`**. That's how "infra blip" is told apart from "bug".

</div>

</div>
<div>

| Action | Restarts | Budget |
|---|---|---|
| `FailJobSet` | nothing, stop now | – |
| `RestartJobSet` | **all** Jobs | spends 1 |
| `RestartJob` <span class="chip alpha">alpha</span> | **only the failed** Job | spends 1 |
| `RestartJobSetAndIgnoreMaxRestarts` | all Jobs | free |
| `RestartJobAndIgnoreMaxRestarts` <span class="chip alpha">alpha</span> | failed Job | free |

<div class="callout fail mt-4 text-sm" v-click>

No rule matches → default `RestartJobSet`. Budget gone → <span class="chip fail">Failed</span> `ReachedMaxRestarts`.

</div>

</div>
</div>

<!--
Three things: rules are ordered, maxRestarts is a budget, and the action picks the blast radius.
Every pod in this demo waits for a trigger file: /tmp/crash exits 1, /tmp/preempt exits 42.
-->

---

<div class="eyebrow"><b>Failure demo</b> · three triggers, three behaviours <span class="nb">▶ NB 3.2 – 3.5</span></div>

# One JobSet, three kinds of failure

<div class="grid grid-cols-3 gap-4 mt-1">
<div>

### ① A worker crashes

<Term cmd="kubectl exec resilient-workers-1-0-… -- touch /tmp/crash">

```text {4}
NAME                         STATUS    AGE
resilient-leader-0-0-h2k9d   Running   2m
resilient-workers-0-0-p7xq   Running   2m
resilient-workers-1-0-v3n8   Running   6s
resilient-workers-2-0-f9wz   Running   2m
```

</Term>

<p class="text-xs mt-2"><b>worker-down → RestartJob.</b> Only <code>workers-1</code> is new. Everyone else kept running.</p>

</div>
<div v-click>

### ② The leader is "preempted"

<Term cmd="kubectl exec resilient-leader-0-0-… -- touch /tmp/preempt">

```text
NAME                         STATUS    AGE
resilient-leader-0-0-q8x2m   Running   5s
resilient-workers-0-0-z1c4   Running   5s
resilient-workers-1-0-k7p0   Running   5s
resilient-workers-2-0-b3n9   Running   5s
```

</Term>

<p class="text-xs mt-2"><b>infra-blip → RestartJobSetAndIgnoreMaxRestarts.</b> Every pod is new, but the restart is free.</p>

</div>
<div v-click>

### ③ The leader has a bug

<Term cmd="kubectl exec resilient-leader-0-0-… -- touch /tmp/crash">

```text
NAME                         STATUS    AGE
resilient-leader-0-0-m5r1w   Running   4s
resilient-workers-0-0-d2k8   Running   4s
resilient-workers-1-0-x6t3   Running   4s
resilient-workers-2-0-n0q5   Running   4s
```

</Term>

<p class="text-xs mt-2"><b>leader-down → RestartJobSet.</b> Everything restarts, and it spends the budget.</p>

</div>
</div>

<div v-click class="mt-3">

<Term cmd="kubectl get jobset resilient -o json | jq -c '.status | {restarts, restartsCountTowardsMax}'">

```text
{"restarts":2,"restartsCountTowardsMax":1}
```

</Term>

</div>

<!--
restarts = 2 global restarts (preempt + bug), but only 1 counts towards maxRestarts. The single-Job restart from step 1 is tracked per Job in replicatedJobsStatus[].jobRestarts.
Only use RestartJob when ranks can rejoin on their own. Many collective-communication frameworks can't, so they need RestartJobSet.
-->
