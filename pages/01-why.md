---
layout: section
class: section
---

<div class="section-num">01</div>

# Why a Job isn't enough

<p class="lede">A quick refresher on what a Kubernetes Job does well, and where it stops.</p>

---

<div class="eyebrow"><b>Refresher</b> · batch/v1 Job <span class="nb">▶ NB 1.1</span></div>

# A Job runs pods until they finish

<div class="grid grid-cols-2 gap-8 mt-4">
<div>

```yaml {all|7-9|10|13-17}
# demo/manifests/00-plain-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: hello-batch
spec:
  completions: 3
  parallelism: 3
  completionMode: Indexed
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: worker
        image: busybox:1.37
        command: ["sh","-c","echo $JOB_COMPLETION_INDEX"]
```

</div>
<div>

<Term cmd="kubectl apply -f manifests/00-plain-job.yaml">

```text
job.batch/hello-batch created
```

</Term>

<Term cmd="kubectl get pods -l job-name=hello-batch">

```text
NAME                  READY   STATUS      RESTARTS   AGE
hello-batch-0-7xk2p   0/1     Completed   0          12s
hello-batch-1-q9d4m   0/1     Completed   0          12s
hello-batch-2-l5vbn   0/1     Completed   0          12s
```

</Term>

<div class="callout mt-4" v-click>

Run to completion ✓ · retries ✓ · parallelism ✓ · indexes ✓<br>
But there's **one pod template**, and every pod is **interchangeable**.

</div>
</div>
</div>

<!--
Walk the highlights: completions/parallelism, indexed mode gives each pod a stable index, backoffLimit, and one template.

Key point: a Job is a homogeneous bag of pods. Remember that phrase.
-->

---

<div class="eyebrow"><b>The problem</b> · distributed training on 3 nodes</div>

# Distributed workloads need four things a Job can't express

<div class="needs mt-8">
<div class="need" v-click>
  <span class="n">1</span>
  <h4>Different roles</h4>
  <p>A leader/driver plus N workers, or parameter servers. Each role needs its own image, resources and command.</p>
</div>
<div class="need" v-click>
  <span class="n">2</span>
  <h4>Stable identity</h4>
  <p>Rank 0 must be reachable at a <em>name</em> that survives restarts. Pod IPs change on every restart.</p>
</div>
<div class="need" v-click>
  <span class="n">3</span>
  <h4>Start together</h4>
  <p>If 7 of 8 ranks schedule, the 7 sit idle holding GPUs, waiting on the 8th at the first all-reduce.</p>
</div>
<div class="need" v-click>
  <span class="n">4</span>
  <h4>Fail and succeed as a unit</h4>
  <p>If one rank dies, the others are useless. Restart the group from the last checkpoint, or stop it.</p>
</div>
</div>

<div class="callout fail mt-10" v-click>

The same shape shows up outside AI: MPI launcher + workers, Spark-style driver + executors, simulation coordinators.

</div>

<!--
This is the core motivation slide. Each of these four maps to a JobSet feature we'll see later:
1 → replicatedJobs, 2 → network / headless service, 3 → gang scheduling, 4 → failure & success policies.
-->

---

<div class="eyebrow"><b>Before JobSet</b> · the DIY approach</div>

# Without JobSet, you write the glue yourself

<div class="versus mt-6">
<div>

### What teams hand-wire

<div class="stack-item messy">Job: leader (1 pod)</div>
<div class="stack-item messy">Job: workers (N pods)</div>
<div class="stack-item messy">Service: headless, hand-matched selectors</div>
<div class="stack-item messy">hostname / subdomain patched into every pod</div>
<div class="stack-item messy glue">script: "if any Job fails, delete all and re-create"</div>
<div class="stack-item messy glue">script: "wait until leader is up before workers"</div>
<div class="stack-item messy glue">cron: clean up finished objects</div>

</div>
<div v-click>

### With JobSet

<div class="one-object">
<div class="font-bold text-[0.8rem]" style="color:var(--k8s)">kind: JobSet</div>
<div class="mt-3 text-[0.68rem] leading-6">
→ child Jobs per role<br>
→ headless Service + per-pod DNS<br>
→ failure & success policies<br>
→ startup ordering / dependencies<br>
→ TTL cleanup, suspend, Kueue, gang scheduling
</div>
</div>

<p class="text-sm mt-4">One declarative object, one lifecycle, reconciled by a controller.</p>

<p class="text-xs mt-2 opacity-80">A CRD + controller from Kubernetes SIG Apps / WG Batch (<code>jobset.x-k8s.io/v1alpha2</code>). Your Job templates stay plain <code>batch/v1</code>. It's also the foundation of Kubeflow Trainer v2.</p>

</div>
</div>

<!--
The red dashed items are the fragile bits: imperative scripts that break under partial failure.
JobSet replaces all of it with one API object.
-->
