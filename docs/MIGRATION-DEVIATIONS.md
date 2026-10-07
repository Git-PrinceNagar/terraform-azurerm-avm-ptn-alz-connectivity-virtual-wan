# Migration deviations

Deviations from the migration guidance in
[`.github/skills/avm-tf-migration/SKILL.md`](../.github/skills/avm-tf-migration/SKILL.md).

## `removed` + `import` is not supported in the AzAPI migration release

The module ships in-module `moved` blocks, which Terraform resolves before `removed` and `import`
blocks, so a consumer-written removed+import artifact has no effect.

## Root `retry`/`timeouts` defaults moved into locals

TFFR7 requires `retry` and `timeouts` to cascade unchanged. The published root variables carried
non-null defaults (four retry regexes, 60m/5m/60m/60m), which would have overwritten the Virtual
WAN submodule's per-resource defaults (for example 90m for a firewall) on every plan. The defaults
now live in `locals.retry.tf` and `locals.timeouts.tf`; the variables keep their name, shape and
`default = {}` but their attributes are `optional(...)` without a default. The only visible change
is that a value you set now also reaches the Virtual WAN resources.

## `ignore_body_changes` keys from `v0.18.0` kept as deprecated aliases

The published baseline `0.17.2` has no root `ignore_body_changes` input, so baseline callers are unaffected.
Release `v0.18.0` introduced it with three
top-level keys; this branch reshapes it to mirror the submodule and keeps those three keys, which are
accepted and merged into the new ones (see `locals.ignore_body_changes.tf`). Which version ships this
change is `v0.19.0`.
