rule "terraform_module_pinned_source" {
  enabled = false
}

# ===========================================================================
# TFFR3 (Severity-MUST; Class-Resource, Class-Pattern, Class-Utility) --
# RECORDED BREACH, examples scope.
#
# This repository BREACHES TFFR3 here. This block is not a permitted exception
# and does not claim one: it records a breach and states the exit plan.
#
# SCOPE. This file is merged over `avm.tflint_example.hcl`, which the AVM
# tooling applies to EACH `examples/*` DIRECTORY, one level deep
# (`Invoke-AvmTerraformLint.ps1` L75-77). It does not reach the repository root
# (which declares no azurerm provider) and it does not reach `modules/*` (that
# is `avm.tflint_module.override.hcl`, deliberately left alone -- every
# submodule is pure AzAPI).
#
# A per-directory `avm.tflint.override.hcl` inside a single example would be
# narrower still, but it would not be narrower in EFFECT: every example that
# declares `provider "azurerm"` instantiates the same azurerm-requiring registry
# module, so per-directory files would carry the same breach record repeatedly.
#
# ⚠️ THIS DOES NOT MAKE A BUILD PASS. The rule is already `severity =
# "notice"` in the immutable base (`plugin "avm"` v1.0.0) and the default
# failure threshold is `warning`, so it cannot fail `avm pr-check` today. The
# disable exists to RECORD THE BREACH EXPLICITLY, not to silence a failure.
#
# WHY THE EXAMPLES STILL DECLARE AND CONFIGURE `hashicorp/azurerm`. No example declares an
# `azurerm_*` resource or data source. Each declares the provider, and a
# `provider "azurerm" { features {} }` block, because it instantiates the registry module
# `Azure/avm-res-resources-resourcegroup/azurerm` (0.2.0), which declares `hashicorp/azurerm`
# in its own `required_providers`. It is used by these examples: firewall-policy-alternative-region,
# full-multi-region, minimal-config, route-map, virtual-hub-with-network-connections
# and vpn-site-connection-dpd-timeout. Every other module the examples reach is azurerm-free.
#
# EXIT PLAN: move the examples to an azurerm-free release of the resource group module.
# Doing so is a state migration of its own (it ships `moved` blocks), so it is taken as a
# separate change from this one.
# ===========================================================================
rule "avm_provider_azurerm_disallowed" {
  enabled = false
}
