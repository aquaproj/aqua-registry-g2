---
name: review-pull-request
description: Read a pull request ar2 opened in aqua-registry-g2 and decide whether it can merge. Use when a pull request is waiting for a person, when asked why one hasn't merged itself, and when asked to review the registry's open pull requests.
---

# Review a pull request from ar2

Most of them merge themselves, and the trust in that comes from CI rather than from
anyone's judgement: it downloads every asset the generated files describe, on a machine of
the environment each entry is for, checks the checksums, opens the archives and verifies
every signature the entries claim.

So a pull request waiting for a person is one ar2 decided it could not answer for, or one
a person asked for. Its body says which, and what to do about each is in
[docs/review-pr.md](../../docs/review-pr.md).
