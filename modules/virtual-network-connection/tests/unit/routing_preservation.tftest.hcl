mock_provider "azapi" {
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        value = [{
          name = "connection-test"
          properties = {
            allowHubToRemoteVnetTransit         = true
            allowRemoteVnetToUseHubVnetGateways = true
            remoteVirtualNetwork = {
              id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test"
            }
            routingConfiguration = {
              associatedRouteTable = {
                id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/virtualHubs/hub-test/hubRouteTables/custom"
              }
              propagatedRouteTables = {
                labels = ["custom"]
                ids    = []
              }
              vnetRoutes = {
                staticRoutes = [{
                  name             = "custom-route"
                  addressPrefixes  = ["10.42.0.0/16"]
                  nextHopIpAddress = "10.0.0.4"
                }]
                staticRoutesConfig = {
                  propagateStaticRoutes          = false
                  vnetLocalRouteOverrideCriteria = "Equal"
                }
              }
            }
          }
        }]
      }
    }
  }
}

variables {
  virtual_network_connections = {
    test = {
      name                      = "connection-test"
      virtual_hub_id            = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/virtualHubs/hub-test"
      remote_virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test"
    }
  }
}

run "omitted_routing_preserves_existing_custom_routing" {
  command = plan

  assert {
    condition     = try(azapi_resource.this["test"].body.properties.routingConfiguration.associatedRouteTable.id, null) == "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/virtualHubs/hub-test/hubRouteTables/custom"
    error_message = "Omitted routing must retain the existing route-table association, not reset it to defaults."
  }
  assert {
    condition     = try(azapi_resource.this["test"].body.properties.routingConfiguration.vnetRoutes.staticRoutes[0].nextHopIpAddress, null) == "10.0.0.4"
    error_message = "Omitted routing must retain existing custom static routes."
  }
  assert {
    condition     = try(azapi_resource.this["test"].body.properties.routingConfiguration.vnetRoutes.staticRoutesConfig.propagateStaticRoutes, null) == false
    error_message = "Omitted routing must retain custom static-route propagation settings."
  }
  assert {
    condition     = azapi_resource.this["test"].body.properties.allowHubToRemoteVnetTransit && azapi_resource.this["test"].body.properties.allowRemoteVnetToUseHubVnetGateways
    error_message = "Returned legacy transit flags must not be removed during adoption."
  }
}

run "explicit_routing_overrides_existing_routing" {
  command = plan

  variables {
    virtual_network_connections = {
      test = {
        name                      = "connection-test"
        virtual_hub_id            = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/virtualHubs/hub-test"
        remote_virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test"
        routing = {
          associated_route_table_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/virtualHubs/hub-test/hubRouteTables/explicit"
          propagated_route_table    = { labels = ["explicit"] }
        }
      }
    }
  }

  assert {
    condition     = azapi_resource.this["test"].body.properties.routingConfiguration.associatedRouteTable.id == "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/virtualHubs/hub-test/hubRouteTables/explicit"
    error_message = "Explicit routing must override the existing association."
  }
  assert {
    condition     = azapi_resource.this["test"].body.properties.routingConfiguration.propagatedRouteTables.labels[0] == "explicit"
    error_message = "Explicit propagation labels must be honored."
  }
}

run "fresh_connection_keeps_azure_routing_defaults" {
  command = plan

  override_data {
    target = data.azapi_resource_list.virtual_network_connections["test"]
    values = { output = { value = [] } }
  }

  assert {
    condition     = !contains(keys(azapi_resource.this["test"].body.properties), "routingConfiguration")
    error_message = "A new connection with omitted routing must use Azure defaults."
  }
}

run "connection_to_another_vnet_does_not_inherit_routing" {
  command = plan

  variables {
    virtual_network_connections = {
      test = {
        name                      = "connection-test"
        virtual_hub_id            = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/virtualHubs/hub-test"
        remote_virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/different-vnet"
      }
    }
  }

  assert {
    condition     = !contains(keys(azapi_resource.this["test"].body.properties), "routingConfiguration")
    error_message = "A replacement targeting another VNet must not inherit unrelated routing."
  }
}
