---
theme: default
colorSchema: light
title: Beyond Kubernetes Jobs
info: |
  ## Beyond Kubernetes Jobs: Running Distributed Workloads with JobSet
  A zero-to-one, example-driven tour of JobSet: core concepts, lifecycle,
  failure handling, coordination and gang scheduling.
author: '@evalsocket'
keywords: kubernetes,jobset,batch,gang-scheduling,cncf
fonts:
  sans: Space Grotesk
  mono: JetBrains Mono
  weights: '400,500,600,700'
highlighter: shiki
lineNumbers: false
drawings:
  persist: false
transition: slide-left
mdc: true
duration: 45min
layout: cover
class: cover
---

<div class="cover-kicker">CNCF · Batch on Kubernetes</div>

<h1 class="cover-title">Beyond Kubernetes Jobs<br><em>Running distributed workloads with JobSet</em></h1>

<p class="cover-sub">From one Job to many coordinated Jobs: concepts, lifecycle, failure handling and gang scheduling, with every command run live.</p>

<div class="cover-meta abs-bl m-14 mb-12 w-[calc(100%-7rem)] flex justify-between">
  <span>@evalsocket</span>
  <span>jobset.sigs.k8s.io</span>
</div>

<!--
Welcome. Ask the room: who has run a Kubernetes Job? Who has tried to run distributed training on Kubernetes? That's the gap this talk fills.

Everything I show today runs on a laptop kind cluster. The manifests are in the demo/ folder, so you can follow along later.
-->

---
layout: default
---

<div class="eyebrow"><b>Roadmap</b> · 45 minutes, zero to one, live</div>

# What we'll build up, one step at a time

<div class="grid grid-cols-[1fr_1.1fr] gap-10 mt-6">
<div>

<v-clicks>

1. **Why** a Job isn't enough for distributed work
2. **Your first JobSet**: roles, naming, DNS, coordinator, and what happens behind the scenes
3. **Lifecycle**: success policy and failure policy
4. **Coordination**: startup order and dependencies
5. **Gang scheduling**: Workload, PodGroup, all-or-nothing, and elastic scaling
6. **Wrap-up**: troubleshooting and what else is in the box

</v-clicks>

</div>
<div class="callout mt-2">

**How to follow along**

The command is in the terminal's title bar and its output is underneath.

<Term cmd="kubectl get jobset">

```text
NAME    TERMINALSTATE   RESTARTS   COMPLETED   SUSPENDED   AGE
hello                   0                      false       20s
```

</Term>

<span class="nb" style="margin-left:0">▶ NB 2.1</span> on a slide = run that step in `demo/jobset-demo.ipynb`. One cluster (`demo/cluster.sh up`) runs every demo.

</div>
</div>

<!--
Set expectations: no prior JobSet knowledge needed. If you know what a Pod and a Job are, you're good.

Point at the terminal convention once, so you don't have to explain it again.
-->

---
src: ./pages/01-why.md
---

---
src: ./pages/02-first-jobset.md
---

---
src: ./pages/03-lifecycle.md
---

---
src: ./pages/04-coordination.md
---

---
src: ./pages/05-gang.md
---

---
src: ./pages/06-wrap.md
---
