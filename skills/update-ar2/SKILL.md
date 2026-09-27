---
name: update-ar2
description: Raise the pinned ar2 version in aqua-registry-g2, and release ar2 itself. Use when a change to ar2 has to reach the registry, or when the pin is behind what ar2 has released.
---

# Update the pinned ar2

Renovate raises the pinned version in `aqua/aqua.yaml`, and autofix.ci records the
checksums, which is what makes such a pull request mergeable. A bump by hand records them
in the same commit instead:

```sh
aqua upc -prune
```

Releasing ar2 is a signed tag on its repository; the release workflow does the rest.
