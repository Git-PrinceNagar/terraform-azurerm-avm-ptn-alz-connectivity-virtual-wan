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
top-level keys. Release `v0.19.0` reshapes it to mirror the submodule and keeps those three keys, which are
accepted and merged into the new ones (see `locals.ignore_body_changes.tf`).

## Virtual WAN Office365 schema validation exception

`office365_local_breakout_category` remains supported with the AzureRM default
`None` and allowed values `None`, `Optimize`, `OptimizeAndAllow` and `All`.
`modules/virtual-wan/main.tf` sends it as
`properties.office365LocalBreakoutCategory` on the existing Virtual WAN writer.
Callers supplying `virtual_wan_id` reference an externally managed WAN; this
module does not write that WAN or change its category.

AzureRM v4.81.0 sets the field on create, reads it into state, and updates it by
merging the changed value into the existing ARM response. Its implementation is
[virtual_wan_resource.go](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/internal/services/network/virtual_wan_resource.go).
AzAPI's embedded schema instead marks the property read-only for API 2025-07-01.
Omitting it while accepting the input silently loses supported behavior.

The historical `o365-readonly/RESULT.md` lab record, amended on 2026-09-26,
reports a hubless WAN PUT with `OptimizeAndAllow` followed by two GETs returning
`Succeeded` and the same value. It also records the AzAPI 2.12.0 schema rejection
and a successful local plan with `schema_validation_enabled = false`.
That measurement supports the exception; it is not a live test of this repair
revision, nor proof of every category or an upgrade with hubs attached.

An isolated lab run at vWAN commit
`7be2e258283ee454669ef43b5e9f5a983b480eb7` created a Standard WAN with
`Optimize` and one attached hub in `centralindia`. ARM readback confirmed the
category and the attached hub's `Succeeded` state; the refreshed replan showed
`No changes`, and all seven managed objects were destroyed afterwards. This
does not establish category updates on an existing WAN, every category, or
preservation of gateways, connections and other child collections during an
upgrade. It is not a full vWAN or Accelerator end-to-end test.

Only `azapi_resource.virtual_wan` sets `schema_validation_enabled = false`.
The flag is resource-wide, so the entire Virtual WAN request body loses embedded
schema validation. Input enum validation remains, and other resources are not
changed. The body is still mutable so category changes can reach ARM; no new
`ignore_changes`, replacement trigger or state address is introduced.
Existing-state upgrades still require a normal-refresh plan, review of every ARM
write and child-collection readback under the upgrade guide. Local mocked tests
cannot establish that an existing estate's full PUT preserves all child objects.

## Full-multi-region example's Accelerator client-config dependency

The resource-group calls in all six affected examples use the AzAPI
implementation in resourcegroup `0.4.0`. The full-multi-region example still
needs AzureRM for its remote Accelerator config-templating utility, not for
resource-group or vWAN provisioning. Removing that provider would break the
utility's `azurerm_client_config` read.

The inspected Accelerator revision is
[`8efcb61c4dc856c7a7c0f227d0aaf5fe39d28661`](https://github.com/Azure/alz-terraform-accelerator/tree/8efcb61c4dc856c7a7c0f227d0aaf5fe39d28661/templates/platform_landing_zone/modules/config-templating).
Its `data.tf` reads the client configuration, and `locals.config.tf` uses the
tenant ID when the root management-group input is empty. AzAPI can provide that
value, so this is a residual upstream dependency, not an AzAPI capability
exception. The example retains its existing remote source rather than copying
or modifying the upstream utility.

The example provider-graph regression permits AzureRM declarations only at the
full-multi-region root and that utility. No global AzureRM-disallowed lint
suppression remains. Remove this example-only provider configuration after the
upstream utility has a compatible AzAPI implementation and its rendered outputs
and resolved graph have been checked. The remote source still tracks `main`;
the inspected revision is evidence, not a pin or a promise about future heads.
