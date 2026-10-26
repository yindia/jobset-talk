---
layout: section
class: section
---

<div class="section-num">04</div>

# Coordination: who starts first?

<p class="lede">Workers that start before the leader is listening crash-loop and burn your restart budget. Fix that with configuration, not sleep loops.</p>

---

<div class="eyebrow"><b>Ordering</b> · two tools</div>

# InOrder startup vs. DependsOn

<div class="grid grid-cols-2 gap-8 mt-2">
<div>

### startupPolicy: a simple chain

```yaml
spec:
  startupPolicy:
    startupPolicyOrder: InOrder
  replicatedJobs:
  - name: driver    # 1st: must become Ready
    ...readinessProbe...
  - name: workers   # 2nd: created after that
```

<p class="text-sm">List order only · waits for <b>Ready</b> only.</p>

</div>
<div>

### dependsOn: a per-role graph

```yaml
replicatedJobs:
- name: initializer          # download model
- name: launcher
  dependsOn:
  - name: initializer
    status: Complete         # must FINISH
- name: worker
  dependsOn:
  - name: launcher
    status: Ready            # must be SERVING
```

<p class="text-sm">Any order · <b>Complete</b> or <b>Ready</b> · fan-in/fan-out.</p>

</div>
</div>

<div class="callout mt-4" v-click>

Rule of thumb: "leader up before workers" → **InOrder**. "Data prep must finish, *then* the server must be up, *then* workers" → **dependsOn**.

</div>

<!--
Use one or the other. Both create Jobs sequentially, which matters for gang scheduling later: one JobSet-wide gang can't be combined with them.
-->

---

<div class="eyebrow"><b>Coordination demo</b> · demo/manifests/03-pipeline.yaml <span class="nb">▶ NB 4.1</span></div>

# Watch the dependency graph unfold

<div class="states mt-4 mb-6 justify-center">
  <span class="state">initializer</span><span class="arrow">— Complete →</span>
  <span class="state">launcher</span><span class="arrow">— Ready →</span>
  <span class="state">worker ×4</span>
</div>

<div class="grid grid-cols-3 gap-4">
<div>

<Term cmd="kubectl get jobs -l …=pipeline   # t≈5s">

```text
NAME                    STATUS
pipeline-initializer-0  Running
```

</Term>

</div>
<div v-click>

<Term cmd="kubectl get jobs -l …=pipeline   # t≈20s">

```text
NAME                    STATUS
pipeline-initializer-0  Complete
pipeline-launcher-0     Running
```

</Term>

</div>
<div v-click>

<Term cmd="kubectl get jobs -l …=pipeline   # t≈30s">

```text
NAME                    STATUS
pipeline-initializer-0  Complete
pipeline-launcher-0     Running
pipeline-worker-0       Running
```

</Term>

</div>
</div>

<div class="callout ok mt-6" v-click>

The `worker` Job **doesn't exist** until the launcher is Ready, so nothing crash-loops and no restart budget is wasted.

</div>

<!--
Full selector: -l jobset.sigs.k8s.io/jobset-name=pipeline. The notebook polls and prints a snapshot every few seconds.
The launcher's "Ready" comes from its startupProbe.
-->
