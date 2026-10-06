# Changelog

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This is the first entry;
prior releases were not retroactively logged here.

## [Unreleased]

### Changed

- Root `retry` and `timeouts` are now cascaded to `module.virtual_wan` (TFFR7), so a value you set
  reaches every Virtual WAN resource, including both firewall modes (managed and customer public
  IPs). Before this, they only reached the sidecar virtual network, route maps and firewall
  policies. The inline defaults moved from the two variables into `locals.retry.tf` and
  `locals.timeouts.tf`: an unset attribute is passed down as null and each receiving module keeps
  its own default, so nothing changes when you set neither. The firewall keeps 90m for create,
  update and delete and 5m for read. The root's own children keep the four-regex retry and the
  60m/5m/60m/60m timeouts.
- `ignore_body_changes` accepts the keys that the `v0.18.0` git tag introduced, `virtual_hubs_firewalls`,
  `virtual_hubs_firewalls_diagnostic_settings` and `virtual_hubs_route_maps` again, as deprecated
  aliases merged into `network_virtual_wans.network_azure_firewalls.*` and
  `network_virtual_hubs_route_maps`. Move to the new keys when convenient.

### Fixed

- A labelled `virtual_hub_route_table` with no `routes` failed to plan
  (`Cannot use a null value in for_each`). `routes` is `optional(map(...))` with no default, so
  omitting it (a legitimate, label-only route table) reached
  `dynamic "route" { for_each = each.value.routes }` as `null`. Guarded at
  `modules/virtual-wan/locals.tf:126` — pre-existing since v0.16.1, unaffected configurations see no
  behaviour change. Two related defects remain open and are filed separately after this release:
  the P2S server-config key lookup and the hub `resource_group_name` fallback (see the maintainer's
  validation notes for file:line and repro).
