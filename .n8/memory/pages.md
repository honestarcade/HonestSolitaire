---
name: pages
description: How the privacy policy is published, and what that makes public
metadata:
  type: project
---

# GitHub Pages

- **URL:** <https://honestarcade.github.io/HonestSolitaire/> — the policy is at
  `/privacy`, the URL entered in the Play Console.
- **Source:** `main` branch, `/docs` folder, Jekyll with the primer theme;
  `docs/privacy.md` carries `permalink: /privacy`.
- **Everything under `docs/` is public.** Nothing but the site belongs there.
- Enabled with
  `gh api -X POST repos/honestarcade/HonestSolitaire/pages --input -` and body
  `{"source":{"branch":"main","path":"/docs"}}`; the fallback is Settings →
  Pages → Deploy from a branch → `main` / `/docs`. Builds are asynchronous:
  `/privacy` can 404 for a few minutes after enabling.
