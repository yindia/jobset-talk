# Beyond Kubernetes Jobs: Running Distributed Workloads with JobSet

Slides and live demo for a CNCF talk: a zero-to-one, example-driven tour of
[JobSet](https://jobset.sigs.k8s.io/). It covers roles, naming and DNS, success
and failure policies, startup ordering, gang scheduling with Workload-Aware
Scheduling (Workload / PodGroup), and elastic scaling.

- **Slides:** [Slidev](https://sli.dev), 38 slides, about 45 minutes with the live demo
- **Demo:** one kind cluster script plus a Jupyter notebook whose steps match the
  `▶ NB x.y` chips on the slides

## Slides

```bash
npm install
npm run dev          # http://localhost:3030 (presenter mode: /presenter)
npm run build        # static site in dist/ (Netlify and Vercel configs included)
npm run export:pdf   # dist/beyond-kubernetes-jobs.pdf
npm run export:pptx  # dist/beyond-kubernetes-jobs.pptx
```

## Live demo

Needs `docker`, `kind`, `kubectl`, `jq`, and Python 3 with Jupyter.

```bash
cd demo
./cluster.sh up                  # kind (Kubernetes 1.37, WAS on) + JobSet, 3 workers x 2 fake GPUs
jupyter lab jobset-demo.ipynb    # run NB 0 first, then follow the slides
./cluster.sh reset               # between rehearsals
./cluster.sh down                # delete the cluster
```

See [`demo/README.md`](demo/README.md) for what each manifest shows.

## Layout

| Path | Contents |
|------|----------|
| `slides.md` | Headmatter, cover, roadmap; imports each section |
| `pages/01-why.md` … `pages/06-wrap.md` | One file per section |
| `components/Term.vue` | Terminal window: command in the title bar, output in the slot |
| `styles/index.css` | Design tokens and slide styles |
| `demo/` | `cluster.sh`, `manifests/`, `jobset-demo.ipynb` |

## License

Apache-2.0
