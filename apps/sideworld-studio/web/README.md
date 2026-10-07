# SIDEWORLD Studio V0-A

Private SIDEWORLD authoring application shell.

V0-A intentionally contains **no database grants, no database reads, and no authoring writes**. It establishes the separate Studio app, navigation shell, visual identity and CI boundary. V0-B will add reviewed server-side reads and Canon Inspector.

The `/studio` route in this PR is a non-production shell preview; real editor authentication is part of the next reviewed security slice before deployment.
