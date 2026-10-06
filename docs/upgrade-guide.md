# Upgrade guide — moving this module from AzureRM to AzAPI

This release replaces every `hashicorp/azurerm` resource this module declares with `Azure/azapi`
equivalents. Your Virtual WAN, hubs, gateways, connections, VPN sites and firewall are **not**
recreated: the module ships `moved` blocks that convert your state in place.

**Two rules for the whole upgrade.** Plan with a normal refresh — **never `-refresh=false`**, see
[Known limitations](#known-limitations) — and treat a `destroy` or a `replace` on a Virtual WAN
object as a stop, not something to approve.

## If you use the ALZ Landing Zones Accelerator

**Take the latest Accelerator starter release and re-run the Accelerator. There is nothing else to
do** — the starter owns both the module version pin and the `providers` map, so the version bump and
the required `azapi` provider line arrive together. Re-plan, confirm `0 to destroy` with nothing
replaced, and apply.

> ⚠️ **Starter releases up to and including v17.5.1 pass only `azurerm`.** If yours is one of them,
> open `main.connectivity.virtual.wan.tf` in your generated root and add the `azapi` line to the
> `module "virtual_wan"` call by hand before you plan — without it every resource lands in the wrong
> subscription and the upgrade plans as a full replace:
>
> ```hcl
> providers = {
>   azurerm = azurerm.connectivity
>   azapi   = azapi.connectivity
> }
> ```

## If you call this module directly

### Before you start

1. **Back up your state file and know how to restore it.** The upgrade is one plan and one apply; an
   interrupted apply needs manual repair from the pre-apply state.
2. **Read your child objects back from ARM first** — `vpnConnections`, `natRules`,
   `expressRouteConnections` — and compare the counts afterwards. A plan is not evidence a child survived.
3. **Apply a saved, reviewed plan**, and never re-plan between review and apply.

### 1. You must be on v0.12.0 or later

The only supported starting point is **`>= v0.12.0`** — the release that introduced
`modules/virtual-wan/` and its eight `moved` blocks, which this release's own moves are written against.

If you are **below v0.12.0**, this is a two-hop upgrade: first move to **v0.17.2** — the final
AzureRM release — apply, confirm `No changes.`, and only then run this upgrade as a separate change.
Do not combine the hops; a `moved` block cannot cross resource types.

### 2. Raise your Terraform floor to 1.11

`modules/site-to-site-gateway-connection` declares `required_version = "~> 1.11"`. It sends the
per-link pre-shared key through AzAPI's write-only `sensitive_body`, and write-only attributes do not
exist before Terraform 1.11, so a 1.10 CLI fails while loading the provider schema at plan time.
**The floor binds every caller, whether or not you set a key.**

### 3. Pass the `azapi` provider — required, and breaking

Resource placement used to come from the `azurerm` provider you passed. It now comes from the
`azapi` provider the module receives, and a call that omits it silently inherits your root's default
`azapi` provider. Add the line before you plan:

```hcl
module "virtual_wan" {
  source  = "Azure/avm-ptn-alz-connectivity-virtual-wan/azurerm"
  version = "<the new version>"
  # ... your existing inputs, unchanged

  providers = {
    azurerm = azurerm.connectivity
    azapi   = azapi.connectivity # REQUIRED
  }
}
```

If you have no `azapi` provider for that subscription yet, declare one with
`alias = "connectivity"` and `subscription_id = var.subscription_ids["connectivity"]`.

### 4. Bump the version and plan

```bash
terraform init -upgrade
terraform plan -out=tfplan      # a NORMAL refresh. Never -refresh=false.
```

**That is the whole upgrade.** You write nothing else: no `import` blocks, no addresses to look up,
no artifact, nothing to clean up afterwards. Sixteen in-module `moved` blocks do the state move.

### 5. Review the plan and apply

```bash
terraform show -json tfplan > tfplan.json
terraform apply tfplan
```

**A good plan is adds and in-place changes, `0 to destroy`, and nothing replaced.** The adds are
day-2 writers this release introduces that had no AzureRM counterpart — they are not new Azure
objects standing in for old ones. Reference upgrades from v0.16.1 planned `4 to add, 7 to change, 0 to destroy` (a direct call to `modules/virtual-wan`) and `14 to add, 206 to change, 0 to destroy` (a full Accelerator estate); both re-planned to `No changes.` after the apply. The adds include a state-only `terraform_data.public_ip_mode` marker per firewall.

Three plan shapes have known causes:

| what you see | cause | what to do |
|---|---|---|
| `must be replaced` with `+ location = "…" # forces replacement` | you planned with `-refresh=false` | re-plan with a normal refresh |
| `must be replaced` with `replace_paths = [["parent_id"]]` | the call does not pass `azapi` | add `azapi = azapi.connectivity` (step 3) |
| a `destroy` with no matching create | an address no `moved` block covers | **stop and report it** — the 16 moves are meant to be complete |

### 6. After the apply

1. Read the children back from ARM and compare with your pre-apply readback.
2. Re-plan **with a normal refresh** and confirm `No changes.`

## Breaking changes

### 1. The `azapi` provider must be passed to the module call

See [step 3](#3-pass-the-azapi-provider--required-and-breaking). Omitting it points every resource
at the wrong subscription and plans a replace of all of them, with
`replace_paths = [["parent_id"]]`. The `moved` blocks do not protect you from this.

### 2. The `resource` output of `modules/firewall` and `modules/route-map`

**Only affects callers who instantiate those submodules directly.** If you consume the root module,
your output surface is unchanged.

The output keeps its name and cardinality, but each element is now an `azapi_resource` object, so the
AzureRM-specific members are gone: `sku_name`, `sku_tier`, `firewall_policy_id`, `virtual_hub` (and
its nested members), `ip_configuration`, `management_ip_configuration`, `dns_servers`,
`dns_proxy_enabled`, `private_ip_ranges`, `threat_intel_mode`, `zones`, `resource_group_name`.
`id`, `name`, `location` and `tags` remain.

| you used to read | read this instead |
|---|---|
| `resource[key].virtual_hub[0].private_ip_address` | `private_ip_address[key]` |
| `resource[key].virtual_hub[0].public_ip_addresses` | `public_ip_addresses[key]` |
| `resource[key].id` / `.name` | `resource_ids[key]` / `resource_names[key]` |
| anything else | `resource_object[key]`, or `resource[key].body.properties.*` |

`resource_object` is the intended replacement — an explicitly projected object whose shape this
module owns. The computed `output` attribute is **empty** (`response_export_values = []`), so do not
read it to recover the lost members. Both `resource` outputs go in the next major.

### 3. Output element types change on four more submodules

`modules/site-to-site-vpn-site`, `modules/virtual-network-connection`,
`modules/site-to-site-gateway-connection` and `modules/expressroute-gateway-connection` keep the same
container shape, order and cardinality for their `resource` output, but each element is now an
`azapi_resource`. `.id`, `.name` and `resource_id` are unchanged; per-attribute reads such as
`.routing_weight` or `.address_cidrs` no longer resolve. `shared_key` is deliberately no longer
returned by the gateway-connection output, because re-emitting it would put the secret back in state.

## Behaviour that changes after the upgrade

- **Tags** are written by one `Microsoft.Resources/tags` PUT per gateway, hub, firewall and P2S
  gateway, which **replaces the whole tag set** — tags applied out of band are removed at upgrade,
  and **tag drift is never reported in a plan**, because the tag writer does not read from ARM.
- The **perpetual `vpn_link.shared_key` diff disappears** for connections this module manages; one
  you declare outside this module is unaffected and keeps diffing.
- **Do not set `sensitive_body_version`.** The module neither accepts nor sets it; key rotation is
  detected automatically, and a stale version was measured to wipe every link on a connection.
- **`routing.inbound_route_map_id` / `routing.outbound_route_map_id` stay silently inert** — they
  were always dropped, and wiring them up would change live infrastructure on your first apply.
- **`express_route_gateway_bypass_enabled` stays inert** and still sends an explicit `false` on
  create, exactly as AzureRM did.
- **`sa_data_size_kb` / `sa_lifetime_sec`**: a non-numeric string now fails with a `tonumber()`
  error instead of a provider schema error.
- **`vpn_site_link_id` and per-link `bgp_enabled` are no longer ForceNew**; what ARM does when you
  change them in place is untested.
- **`terraform apply` can return while ARM is still working** — a tags-only change completes in
  seconds and leaves the resource `Updating` for minutes.
- **Per-path drift suppression is unavailable on the day-2 update writers** (the provider offers no
  such argument there); the only lever is the whole resource.
- **A pre-shared key passed through a root variable still appears in plan JSON** at the variable
  level. This is unchanged by the upgrade.

## Customer-provided firewall public IPs

A firewall whose `ip_configurations` map is non-empty uses the caller-owned public IPs and is written by
`modules/firewall-customer-ip`; a firewall with an empty map keeps the managed public IPs and the writers above.
The mode is recorded in state and cannot be changed by a normal apply: moving an existing firewall between managed
and customer modes fails with an error and needs a separately planned migration. Customer mode reads the firewall
inventory of the subscription, so the identity needs subscription-scoped read access on `Microsoft.Network/azureFirewalls`.

## How to check the upgrade yourself

1. Deploy the version you run today (`>= v0.12.0`, ideally `v0.17.2`) from your own configuration or from
   `examples/minimal-config` into a test subscription, and keep the state.
2. Change only `version` and the `providers` map, then run `terraform init -upgrade` and
   `terraform plan -out=tfplan` with a normal refresh. Expect `0 to destroy`, nothing replaced, and a
   `has moved to` line for each of your Virtual WAN objects.
3. Save the live objects before and after with `az rest --method get` on each object ID (same `api-version`) and
   compare them leaf by leaf; `etag` and `provisioningState` are expected to differ.
4. Apply the saved plan, then re-plan and expect `No changes.`
5. The module's `terraform test` suites (`tests/unit`, `modules/*/tests`) cover input validation, the firewall
   customer-IP mode and the output shapes without any Azure access.

## What the evidence behind this guide is

Three kinds of evidence exist and they are not interchangeable:

- **Live upgrades.** Upgrades from v0.16.1 on live Azure, with plan, apply, a clean re-plan and a
  leaf-by-leaf comparison of the objects read back from ARM. The five child modules were consumed from pinned
  builds in those runs, not from published registry versions.
- **Mocked unit tests (`terraform test`).** They check input validation, the firewall customer-IP mode, output shapes
  and stable resource identity. They do **not** prove the AzureRM to AzAPI state move: mock providers cannot simulate
  a move across providers, so `tests/unit/firewall_upgrade.tftest.hcl` exercises only the AzAPI code.
- **Same-state upgrade from v0.17.2 with registry-pinned children.** Not yet measured live. Do not read the live
  results above as covering that exact combination.

## Known limitations

- **Do not use `-refresh=false` for the upgrade plan.** This is a hard rule, not a caution. Under
  it the moved state carries a null `location` and an unknown `parent_id`, and the plan reports
  replacements that are not real — measured as `5 to add, 0 to change, 2 to destroy` with
  `+ location = "eastus" # forces replacement` on an object that a normal refresh plans as an
  in-place update. The module's ForceNew preconditions do **not** catch it, because `ignore_changes`
  does not apply to a create. There is no flag, input or version that makes it safe on this upgrade.
  ([azapi#1227](https://github.com/Azure/terraform-provider-azapi/issues/1227))
- **The move records the newest API version embedded in the provider**, not one your configuration
  names — an ARM resource id carries no API version, so the provider picks the newest from its own
  index. In sovereign clouds that version may not exist and the post-move read then fails, and **this
  path has never been measured in a sovereign cloud.** Read the recorded version with
  `terraform state show <address>`; nothing in a plan will remind you.
- **The create-only writer keeps its create-time API version. Changing it is not supported in this
  release.**
- **Live coverage of the `moved` blocks is partial.** Exercised on live ARM during validation: the Virtual
  WAN, hub, firewall, VPN gateway, VPN site and connection, ExpressRoute gateway, hub virtual network
  connection, routing intent, BGP connection, Point-to-Site gateway and server configuration, the module's own
  resource group, the hub route table and the firewall diagnostic setting. **Not exercised live:** the
  ExpressRoute gateway connection, the generated private DNS zone virtual network link moves, and the moves for
  the optional bastion, public IP, DNS resolver and DDoS plan child modules. If your estate has any of those,
  read the plan before you apply and treat a `must be replaced` as a defect in the release.
- **ExpressRoute connections have never been exercised against live ARM** — no circuit was available.
- **`properties.natRules` on VPN gateways is unmeasured** beyond plan level.
- **Destroy ordering with literal IDs.** If a BGP connection refers to its hub virtual network connection by a
  literal ID string rather than a Terraform reference, Terraform has no dependency edge and may delete both in
  parallel; Azure then rejects the connection delete with `HubVnetConnectionInUseByHubBgpConnection`. Re-running
  the destroy after the BGP connection is gone succeeds. Reference the connection through a resource attribute
  or destroy the BGP connection first.
- **Rollback from an interrupted apply is not an established procedure.** A partial apply leaves
  state split and needing manual repair.

A migrated estate can still be destroyed through the module: measured, all-`delete` plan, no
dependency or ordering errors, nothing left behind. Deviations from the AVM specification are
recorded in [`MIGRATION-DEVIATIONS.md`](MIGRATION-DEVIATIONS.md).
