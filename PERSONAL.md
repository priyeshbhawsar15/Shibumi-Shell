# Personal setup fork

Original upstream: https://github.com/HANCORE-linux/Shibumi-Shell
Base revision: `7a6c853b1947d303bad9a5b640c224c01b669106` (`v0.1.1-beta.14.1`).
The original license, attribution, suite ownership and 24-plugin contract remain intact.

This development branch adds the personal bar presentation used by arch-setups:
monitor-description filtering with a reachable fallback, the compact now-playing
notch, theme-token colors, and an auto-hide reveal sensor that does not intercept
media controls. Media state/actions use the existing Shibumi media service;
there is no new player owner, Jellyfin polling process, username-specific helper,
or credential-bearing art cache.

Supported lifecycle additions:

- `install --user-layout` and `activate --user-layout` activate the suite bar
  while recording that its widget layout is user-owned.
- `repair --keep-layout` preserves independent widget configuration while
  transactionally repairing admitted payload. Only explicitly recorded upstream
  predecessor identities are admitted; no marker hashes are rewritten to hide dirt.
- `presentation.mainMonitorDescription` configures the full-controls output.
  Empty selection and single-output hosts retain accessible controls.

Tests: `python3 -m unittest discover -s tests -p 'test_*.py'` (313 tests), and
`node tests/personal-presentation.test.js`. Historical public-package tests build
that exact historical payload from Git rather than treating fork bytes as the
upstream release. The package/production-boundary source checks are included in
the Python suite.

This is a commit-pinned development fork, **not a newly validated upstream
release or binary package**. No tag, AUR package, or release archive is published
by this change. Physical multi-output, theme/hotplug, and clean-VM desktop
acceptance remain separate gates; automated fixtures are not evidence for them.
