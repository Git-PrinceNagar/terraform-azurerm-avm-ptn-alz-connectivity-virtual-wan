# Basic example

This submodule deploys an Azure virtual network connection

## Design notes

### Per-resource timeout defaults

`var.timeouts` keeps its published shape -- same variable name, same four attributes, same
types -- but its attributes no longer carry a blanket `"30m"`/`"5m"` default. Each is now
`optional(string)` (null when unset) and falls back to the timeout default of the `azurerm`
resource this module replaced. A consumer that sets `var.timeouts` today keeps working
unchanged; only the *unset* attributes changed meaning.

**This module's defaults actually change.** `azurerm_virtual_hub_connection` defaulted
create/update/delete to **60 minutes**, not the 30 minutes the migrated module was using. A hub
connection routinely takes longer than half an hour when the hub is busy, so the blanket 30m
could time out an operation AzureRM would have waited out.

Cited against `terraform-provider-azurerm@5782a75422c68a0d0804ac16d97dcaf3df5ee2fa` (v4.81.0):

| `azapi_resource` | AzureRM resource | Source | Create | Read | Update | Delete |
| --- | --- | --- | --- | --- | --- | --- |
| `this` | `azurerm_virtual_hub_connection` | `virtual_hub_connection_resource.go` L37-L42 | 60m | 5m | 60m | 60m |

Passing `var.timeouts = null` still omits the `timeouts` block entirely, exactly as before.
