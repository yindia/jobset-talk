---
layout: section
class: section
---

<div class="section-num">02</div>

# Your first JobSet

<p class="lede">One example, <code>hello</code>, carries us through roles, naming, DNS, the coordinator and what the controller does behind the scenes.</p>

---

<div class="eyebrow"><b>Mental model</b> · three levels of nesting</div>

# JobSet → ReplicatedJob → Job → Pod

<div class="grid grid-cols-[1.35fr_1fr] gap-8 mt-4 items-start">
<div class="tree">
  <div class="tree-box jobset">
    <div class="tree-label"><span>hello</span><span class="kind">JobSet</span></div>
    <div class="tree-row">
      <div class="tree-box rj">
        <div class="tree-label"><span>leader · replicas: 1</span><span class="kind">RJ</span></div>
        <div class="tree-box job">
          <div class="tree-label"><span>hello-leader-0</span><span class="kind">Job</span></div>
          <div class="pods"><span class="pod">leader-0-0</span></div>
        </div>
      </div>
      <div class="tree-box rj">
        <div class="tree-label"><span>workers · replicas: 2</span><span class="kind">RJ</span></div>
        <div class="flex flex-col gap-2">
          <div class="tree-box job">
            <div class="tree-label"><span>hello-workers-0</span><span class="kind">Job</span></div>
            <div class="pods"><span class="pod">workers-0-0</span><span class="pod">workers-0-1</span></div>
          </div>
          <div class="tree-box job">
            <div class="tree-label"><span>hello-workers-1</span><span class="kind">Job</span></div>
            <div class="pods"><span class="pod">workers-1-0</span><span class="pod">workers-1-1</span></div>
          </div>
        </div>
      </div>
    </div>
    <div class="svc">+ headless Service <b>hello</b> → one DNS name per pod</div>
  </div>
</div>
<div class="text-sm leading-7">

<v-clicks>

- **ReplicatedJob** = a role: a Job template plus `replicas`
- `replicas` → how many **Jobs** for that role
- `parallelism` / `completions` → how many **pods** per Job
- Job name: `<jobset>-<rj>-<jobIndex>`
- Pod hostname: `<jobset>-<rj>-<jobIndex>-<podIndex>`

</v-clicks>

<div class="callout mt-4" v-click>
JobSet defaults each Job to <code>completionMode: Indexed</code>, so every pod gets a stable index.
</div>

</div>
</div>

<!--
The one diagram people need to remember. Two knobs for scale: replicas (Jobs) and parallelism (pods per Job).
-->

---

<div class="eyebrow"><b>Demo cluster</b> · demo/cluster.sh <span class="nb">▶ NB 0</span></div>

# One cluster for every demo, gang scheduling included

<div class="grid grid-cols-[1fr_1.1fr] gap-7 mt-1">
<div>

<p class="text-xs mb-2 font-mono opacity-70">kind · Kubernetes 1.37 · 1 control plane + 3 workers · 2 fake GPUs each</p>

<div class="nodes">
  <div class="node"><div class="node-name">worker · rack-a</div><div class="slots"><div class="slot">gpu</div><div class="slot">gpu</div></div></div>
  <div class="node"><div class="node-name">worker2 · rack-a</div><div class="slots"><div class="slot">gpu</div><div class="slot">gpu</div></div></div>
  <div class="node"><div class="node-name">worker3 · rack-b</div><div class="slots"><div class="slot">gpu</div><div class="slot">gpu</div></div></div>
</div>

<div class="text-xs mt-4 leading-6">

<v-clicks>

- **Kubernetes side:** `GenericWorkload` gate + `scheduling.k8s.io/v1beta1` API → Workload / PodGroup and gang scheduling
- **JobSet side** (v0.13.0): `JobSetWorkloadAwareSchedulingAPI`, `ElasticJobSet`, `RestartJob` gates on
- **Fake GPUs:** an extended resource `example.com/gpu` on each worker, so gang demos behave the same on any laptop

</v-clicks>

</div>
</div>
<div>

<Term cmd="./cluster.sh up && ./cluster.sh status">

```text
NODE                        RACK     GPUS
jobset-demo-control-plane   <none>   <none>
jobset-demo-worker          rack-a   2
jobset-demo-worker2         rack-a   2
jobset-demo-worker3         rack-b   2

podgroups.scheduling.k8s.io
priorityclasses.scheduling.k8s.io
workloads.scheduling.k8s.io

featureGates:
  JobSetWorkloadAwareSchedulingAPI: true
  ElasticJobSet: true
  RestartJob: true
```

</Term>

<p class="text-xs mt-2 opacity-80">Run this before the talk: building the 1.37 node image can take a few minutes.</p>

</div>
</div>

<!--
Fake GPUs follow the documented "advertise extended resources for a node" task: a PATCH to node status. Pods request example.com/gpu: 1 like a real GPU.
Notebook section 0 runs the same script and prints this status.
-->

---

<div class="eyebrow"><b>Step 1</b> · demo/manifests/01-hello.yaml <span class="nb">▶ NB 2.1</span></div>

# One manifest: two roles, DNS, coordinator, success policy

<div class="grid grid-cols-[1.1fr_1fr] gap-7 mt-1">
<div>

```yaml {all|6-9|10-12|13-16|17-20|all}{maxHeight:'400px'}
apiVersion: jobset.x-k8s.io/v1alpha2
kind: JobSet
metadata:
  name: hello
spec:
  coordinator:            # who is "rank 0"
    replicatedJob: leader
    jobIndex: 0
    podIndex: 0
  successPolicy:          # done when workers finish
    operator: All
    targetReplicatedJobs: [workers]
  replicatedJobs:
  - name: leader          # 1 Job × 1 pod
    replicas: 1
    template: {...}       # plain batch/v1 Job spec
  - name: workers         # 2 Jobs × 2 pods
    replicas: 2
    template:
      spec: {parallelism: 2, completions: 2, ...}
```

</div>
<div class="text-sm leading-7 pt-2">

<v-clicks at="1">

- **Coordinator:** every pod gets a label with the leader's address
- **Success policy:** finish when `workers` finish, even though the leader never exits
- **leader:** 1 Job
- **workers:** 2 Jobs × 2 pods. Each one looks up the coordinator, pings it, works, then exits

</v-clicks>

<div class="callout ok mt-5" v-click>

**Predict:** 1 + 2 = **3 Jobs**, 1 + 2×2 = **5 Pods**, plus **1 Service**.

</div>
</div>
</div>

<!--
The notebook prints the full file. The slide shows the shape.
Ask the audience to predict the object count before applying.
-->

---

<div class="eyebrow"><b>Behind the scenes</b> · what happens after you hit enter</div>

# `kubectl apply`: from YAML to running Pods

<div class="flow mt-1">
<div class="flow-col">

### Admission · before kubectl returns

<div class="step" v-click><span class="num">1</span><div><span class="actor">kube-apiserver</span><p>Authenticates and authorizes you, and checks the request against the <code>JobSet</code> CRD schema.</p></div></div>
<div class="step" v-click><span class="num">2</span><div><span class="actor">JobSet mutating webhook</span><p>Fills in <b>defaults</b>: <code>startupPolicy: AnyOrder</code>, <code>completionMode: Indexed</code>, <code>restartPolicy: OnFailure</code>, DNS hostnames on.</p></div></div>
<div class="step" v-click><span class="num">3</span><div><span class="actor">JobSet validating webhook + CEL rules</span><p>Rejects bad specs: unknown targets, invalid names, spec changes on a running JobSet. Then it's <b>stored in etcd</b>, and you see <code>created</code>.</p></div></div>

</div>
<div class="flow-col">

### Reconcile · asynchronous, in a loop

<div class="step ctrl" v-click><span class="num">4</span><div><span class="actor">JobSet controller (jobset-system)</span><p>A watch fires. It reads the child Jobs, applies the failure/success policies, then creates the <b>headless Service</b> → PVCs → (WAS) <b>Workload + PodGroups</b> → <b>Jobs</b>, respecting <code>dependsOn</code>/<code>InOrder</code>.</p></div></div>
<div class="step kube" v-click><span class="num">5</span><div><span class="actor">Job controller (kube-controller-manager)</span><p>Creates the indexed <b>Pods</b> for every Job.</p></div></div>
<div class="step kube" v-click><span class="num">6</span><div><span class="actor">kube-scheduler → kubelet</span><p>Binds Pods to nodes (as a <b>gang</b> if they have a PodGroup), and the kubelet starts the containers.</p></div></div>
<div class="step ctrl" v-click><span class="num">7</span><div><span class="actor">JobSet controller, again</span><p>It watches the Jobs it owns, so Job status changes trigger another reconcile, which updates <code>replicatedJobsStatus</code>, conditions and restarts.</p></div></div>

</div>
</div>

<div class="loop-note mt-1" v-click>

↻ **Level-triggered:** every reconcile compares *desired* (the spec) with *actual* (the Jobs it owns) and fixes the difference, so a deleted Job simply comes back.

</div>

<!--
Steps 1–3 are synchronous: a rejected spec never gets stored. Steps 4–7 happen after kubectl returns, which is why "created" doesn't mean "running".
-->

---

<div class="eyebrow"><b>Step 2</b> · apply & inspect <span class="nb">▶ NB 2.2</span></div>

# Apply it: 3 Jobs, 5 Pods, as predicted

<div class="grid grid-cols-2 gap-6 mt-2">
<div>

<Term cmd="kubectl apply -f manifests/01-hello.yaml">

```text
jobset.jobset.x-k8s.io/hello created
```

</Term>

<Term cmd="kubectl get jobset hello">

```text
NAME    TERMINALSTATE   RESTARTS   COMPLETED   SUSPENDED   AGE
hello                   0                      false       20s
```

</Term>

<Term cmd="kubectl get jobs -l jobset.sigs.k8s.io/jobset-name=hello">

```text
NAME              STATUS    COMPLETIONS   DURATION   AGE
hello-leader-0    Running   0/1           20s        20s
hello-workers-0   Running   0/2           20s        20s
hello-workers-1   Running   0/2           20s        20s
```

</Term>

</div>
<div>

<Term cmd="kubectl get pods -l jobset.sigs.k8s.io/jobset-name=hello -L jobset.sigs.k8s.io/replicatedjob-name,jobset.sigs.k8s.io/job-index">

```text
NAME                      STATUS    REPLICATEDJOB-NAME   JOB-INDEX
hello-leader-0-0-5w8zr    Running   leader               0
hello-workers-0-0-g7k2d   Running   workers              0
hello-workers-0-1-m4qtp   Running   workers              0
hello-workers-1-0-zx9cf   Running   workers              1
hello-workers-1-1-b2vhn   Running   workers              1
```

</Term>

<div class="callout mt-3 text-xs" v-click>

Labels you'll use daily (all prefixed `jobset.sigs.k8s.io/`): `jobset-name` · `replicatedjob-name` · `job-index` · `restart-attempt`

</div>

<div class="callout mt-2 text-xs" v-click>

**Gotcha:** the spec is immutable. To change it, `kubectl delete jobset hello` and re-apply. Live edits: `suspend` and (alpha) elastic `parallelism`.

</div>

</div>
</div>

<!--
Pod name = <job>-<podIndex>-<random>. The hostname (next slides) drops the random suffix.
-->

---

<div class="eyebrow"><b>Mental model</b> · the same thing as a tree <span class="nb">▶ NB 2.3</span></div>

# What actually exists in the cluster

<div class="grid grid-cols-[1.1fr_1fr] gap-8 mt-3 items-start">
<div>
<ul class="otree">
  <li><span class="tnode jobset"><span class="k">JobSet</span> hello <span class="by you">you</span></span>
    <ul>
      <li><span class="tnode svc"><span class="k">Service</span> hello <span class="by js">JobSet ctrl</span></span><span class="tnote">headless · DNS per pod</span></li>
      <li><span class="tnode"><span class="k">Job</span> hello-leader-0 <span class="by js">JobSet ctrl</span></span><span class="tnote">rj=leader · idx 0</span>
        <ul>
          <li><span class="tnode pod"><span class="k">Pod</span> …-leader-0-0-5w8zr <span class="by jc">Job ctrl</span></span></li>
        </ul>
      </li>
      <li><span class="tnode"><span class="k">Job</span> hello-workers-0 <span class="by js">JobSet ctrl</span></span><span class="tnote">rj=workers · idx 0</span>
        <ul>
          <li><span class="tnode pod"><span class="k">Pod</span> …-workers-0-0-g7k2d <span class="by jc">Job ctrl</span></span></li>
          <li><span class="tnode pod"><span class="k">Pod</span> …-workers-0-1-m4qtp <span class="by jc">Job ctrl</span></span></li>
        </ul>
      </li>
      <li><span class="tnode"><span class="k">Job</span> hello-workers-1 <span class="by js">JobSet ctrl</span></span><span class="tnote">rj=workers · idx 1</span>
        <ul>
          <li><span class="tnode pod"><span class="k">Pod</span> …-workers-1-0-zx9cf <span class="by jc">Job ctrl</span></span></li>
          <li><span class="tnode pod"><span class="k">Pod</span> …-workers-1-1-b2vhn <span class="by jc">Job ctrl</span></span></li>
        </ul>
      </li>
    </ul>
  </li>
</ul>
</div>
<div class="text-sm">

<v-clicks>

- Every line is an **ownerReference**. Delete the root and everything under it goes too.
- **Who creates what:** <b style="color:var(--wait)">you</b> → JobSet · <b style="color:var(--k8s)">JobSet controller</b> → Service + Jobs · <b style="color:var(--ink-soft)">Job controller</b> → Pods
- **A ReplicatedJob is not an object.** It's a template in the spec, visible only as the `replicatedjob-name` label.

</v-clicks>

<div v-click class="mt-2">

<Term cmd="owner_tree('hello')   # notebook helper, or: kubectl tree jobset hello">

```text
JobSet/hello
├─ Service/hello
├─ Job/hello-leader-0
│  └─ Pod/hello-leader-0-0-5w8zr  [Running]
├─ Job/hello-workers-0
│  ├─ Pod/hello-workers-0-0-g7k2d  [Running]
│  └─ Pod/hello-workers-0-1-m4qtp  [Running]
└─ Job/hello-workers-1
   ├─ Pod/hello-workers-1-0-zx9cf  [Running]
   └─ Pod/hello-workers-1-1-b2vhn  [Running]
```

</Term>

</div>
</div>
</div>

<!--
The notebook builds this tree live from ownerReferences, with no plugin needed. The krew plugin kubectl-tree gives the same view.
People often look for a "ReplicatedJob" object with kubectl and can't find one. This slide is why.
-->

---

<div class="eyebrow"><b>Behind the scenes</b> · see each step for yourself <span class="nb">▶ NB 2.4</span></div>

# Watch the background work happen

<div class="grid grid-cols-[1fr_1.25fr] gap-5 mt-1">
<div>

<Term cmd="kubectl get jobset hello -o yaml   # step 2: defaults">

```text {2-6,11,14}
spec:
  network:
    enableDNSHostnames: true
    publishNotReadyAddresses: true
  startupPolicy:
    startupPolicyOrder: AnyOrder
  replicatedJobs:
  - name: leader
    template:
      spec:
        completionMode: Indexed
        template:
          spec:
            restartPolicy: OnFailure
```

</Term>

<p class="text-xs mt-2 opacity-80">Highlighted = fields you never wrote. The webhook added them.</p>

</div>
<div>

<Term cmd="kubectl get events --sort-by=.lastTimestamp -o custom-columns=FROM:.reportingComponent,REASON:.reason,OBJECT:.involvedObject.name   # steps 5-6">

```text
FROM                REASON             OBJECT
job-controller      SuccessfulCreate   hello-leader-0
job-controller      SuccessfulCreate   hello-workers-0
job-controller      SuccessfulCreate   hello-workers-1
default-scheduler   Scheduled          hello-leader-0-0-5w8zr
kubelet             Pulled             hello-leader-0-0-5w8zr
kubelet             Started            hello-leader-0-0-5w8zr
```

</Term>

<Term cmd="kubectl get jobset hello -o json | jq -c '.status.replicatedJobsStatus[] | {name, ready, active, succeeded}'   # step 7">

```text
{"name":"leader","ready":1,"active":1,"succeeded":0}
{"name":"workers","ready":2,"active":2,"succeeded":0}
```

</Term>

<div class="callout mt-2 text-xs">

`replicatedJobsStatus` counts **Jobs**, not Pods: `workers` has 2 ready Jobs.

</div>

</div>
</div>

<!--
Events come from the Job controller, the scheduler and the kubelet. The JobSet controller mostly emits events when something goes wrong (e.g. JobCreationFailed).
Controller view: kubectl -n jobset-system logs deploy/jobset-controller-manager -f
-->

---

<div class="eyebrow"><b>Networking</b> · same hello JobSet <span class="nb">▶ NB 2.5</span></div>

# Stable names, and a coordinator everyone can find

<div class="grid grid-cols-[1fr_1.1fr] gap-6 mt-1">
<div>

<Term cmd="kubectl get svc hello">

```text
NAME    TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
hello   ClusterIP   None         <none>        <none>    30s
```

</Term>

<Term cmd="kubectl get pods -l jobset.sigs.k8s.io/jobset-name=hello -o custom-columns=HOSTNAME:.spec.hostname,SUBDOMAIN:.spec.subdomain">

```text
HOSTNAME            SUBDOMAIN
hello-leader-0-0    hello
hello-workers-0-0   hello
hello-workers-0-1   hello
hello-workers-1-0   hello
hello-workers-1-1   hello
```

</Term>

<div class="callout mt-3 text-xs">

`<jobset>-<rj>-<job>-<pod>.<subdomain>` → e.g. **`hello-leader-0-0.hello`**. One DNS A record per pod, no ports involved.

</div>

</div>
<div>

<Term cmd="kubectl run dns-test --rm -i --restart=Never --image=busybox:1.37 -- nslookup hello-workers-1-0.hello">

```text
Name:    hello-workers-1-0.hello.default.svc.cluster.local
Address: 10.244.2.7
```

</Term>

<Term cmd="kubectl get pods -l jobset.sigs.k8s.io/jobset-name=hello -L jobset.sigs.k8s.io/coordinator | head -3">

```text
NAME                      READY   STATUS    RESTARTS   AGE   COORDINATOR
hello-leader-0-0-5w8zr    1/1     Running   0          40s   hello-leader-0-0.hello
hello-workers-0-0-g7k2d   1/1     Running   0          40s   hello-leader-0-0.hello
```

</Term>

<Term cmd="kubectl logs -l jobset.sigs.k8s.io/replicatedjob-name=workers --prefix | head -2">

```text
[pod/hello-workers-0-0-g7k2d/worker] worker 0: coordinator is hello-leader-0-0.hello
[pod/hello-workers-0-0-g7k2d/worker] leader reachable
```

</Term>

</div>
</div>

<!--
publishNotReadyAddresses (defaulted true) means DNS works before pods are Ready, which matters because rendezvous happens early.
Coordinator: read via the downward API, e.g. MASTER_ADDR for torchrun. Changing the leader is a one-field change.
-->
