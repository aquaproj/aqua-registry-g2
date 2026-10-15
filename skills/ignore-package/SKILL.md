---
name: ignore-package
description: Stop aqua-registry-g2 trying to generate a package it can't, by adding it to ignored_packages with the reason. Use for a package that fails every run and never will succeed. Not for taking away a package the registry already serves, which is removing one.
---

# Leave a package alone

A package the registry doesn't take on. Nothing was ever published for it, and the reason
is why: an asset whose name carries something only the installing machine knows, downloads
refused from the addresses CI runs on, a command deleted upstream.

`ignored_packages` in [ar2.yaml](../../ar2.yaml), as a pull request into `main`. Each entry
carries its reason, because the next person to wonder why a package isn't here reads that
file and nothing else. They are dropped before anything asks GitHub about them, so a
package whose repository is gone stops costing a request every run.

When the reason holds for every package of an organization -- an IP allow list that refuses
the API to the runners -- write one entry with `name_regexp` instead of one per package:

```yaml
  - name_regexp: aquasecurity/.*
    reason: |
      The aquasecurity organization has an IP allow list enabled, ...
```

The expression has to match the whole name. A run adds the packages aqua-registry gains, so
an entry per package would need another every time the organization gains one. `name` stays
an exact name: read as a regular expression, every dot in it would match any character.

This is not a package being removed, and the two aren't degrees of the same thing: an ignored
package was never published, and [removing one](../remove-package/SKILL.md) takes away what the
registry already serves.
