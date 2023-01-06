// Parameters
@description('Location where resources will be deployed. Defaults to resource group location')
param location string = resourceGroup().location

@description('Cost Centre tag that will be applied to all resources in this deployment')
param cost_centre_tag string

@description('System Owner tag that will be applied to all resources in this deployment')
param owner_tag string

@description('Subject Matter EXpert (SME) tag that will be applied to all resources in this deployment')
param sme_tag string

@description('Synapse workspace name')
param synapse_workspace_name string 

@description('Datalake name')
param synapse_datalake_name string

@description('Datalake SKU. Allowed values are Premium_LRS, Premium_ZRS, Standard_GRS, Standard_GZRS, Standard_LRS,Standard_RAGRS, Standard_RAGZRS, Standard_ZRS')
@allowed([
'Premium_LRS'
'Premium_ZRS'
'Standard_GRS'
'Standard_GZRS'
'Standard_LRS'
'Standard_RAGRS'
'Standard_RAGZRS'
'Standard_ZRS'
])
param synapse_datalake_sku string ='Standard_LRS'

// Variables
var suffix = uniqueString(subscription().subscriptionId)
var synapse_workspace_uniquename = '${synapse_workspace_name}-${suffix}'
var managed_synapse_rg_name = 'mrg_synapse_${resourceGroup().name}'
var synapse_datalake_uniquename = substring('${synapse_datalake_name}${suffix}',0,24)

// Create datalake linked to synapse workspace
resource synapse_storage 'Microsoft.Storage/storageAccounts@2022-09-01' ={
  name: synapse_datalake_uniquename
  location: location
  tags: {
        CostCentre: cost_centre_tag
        Owner: owner_tag
        SME: sme_tag
        }
  sku: {name: synapse_datalake_sku}
  kind:'StorageV2'
  identity: {type: 'SystemAssigned'}
  properties:{
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    isHnsEnabled: true
    minimumTlsVersion: 'TLS1_2'
  }
} 

// Create synapse workspace
resource synapse_workspace 'Microsoft.Synapse/workspaces@2021-06-01'= {
  name: synapse_workspace_uniquename
  location: location
  identity: {type: 'SystemAssigned'}
  tags: {
          CostCentre: cost_centre_tag
          Owner: owner_tag
          SME: sme_tag
        }
  properties:{
        managedResourceGroupName: managed_synapse_rg_name
        defaultDataLakeStorage: { 
            resourceId: synapse_storage.id
            accountUrl: synapse_storage.properties.primaryEndpoints.dfs
            filesystem: synapse_storage.properties.primaryEndpoints.file
          }
        trustedServiceBypassEnabled: true
        }
}

// Create firewall rule to Allow Azure services and resources to access this workspace
resource synapse_workspace_firewallRules 'Microsoft.Synapse/workspaces/firewallRules@2021-06-01' = {
  name: 'AllowAllWindowsAzureIps'
  parent: synapse_workspace
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }
}
