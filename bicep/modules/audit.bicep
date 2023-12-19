// Parameters
@description('Location where resources will be deployed. Defaults to resource group location')
param location string = resourceGroup().location

@description('Cost Centre tag that will be applied to all resources in this deployment')
param cost_centre_tag string

@description('System Owner tag that will be applied to all resources in this deployment')
param owner_tag string

@description('Subject Matter Expert (SME) tag that will be applied to all resources in this deployment')
param sme_tag string

@description('Audit Storage name')
param audit_storage_name string

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
param audit_storage_sku string ='Standard_LRS'

// Variables
var suffix = uniqueString(resourceGroup().id)
var audit_storage_uniquename = substring('${audit_storage_name}${suffix}',0,24)

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: audit_storage_uniquename
  location: location
  tags: {
    CostCentre: cost_centre_tag
    Owner: owner_tag
    SME: sme_tag
    }
  sku: {name: audit_storage_sku}
  kind:  'StorageV2'
  identity: {type: 'SystemAssigned'}
  properties: {
    accessTier: 'Cool'
    allowBlobPublicAccess: true
    isHnsEnabled: true
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

output audit_storage_uniquename string = audit_storage_uniquename
