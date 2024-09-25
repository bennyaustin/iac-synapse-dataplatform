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

@description('Audit Log Analytics Workspace name')
param audit_loganalytics_name string

@description('Flag to indicate whether to enable integration of audit resources with either an existing or new Purview resource')
param enable_purview bool

@description('Resource Name of new or existing Purview Account. Specify a resource name if create_purview=true or enable_purview=true')
param purview_resource object

// Variables
var suffix = uniqueString(resourceGroup().id)
var audit_storage_uniquename = substring('${audit_storage_name}${suffix}',0,24)
var audit_loganalytics_uniquename = '${audit_loganalytics_name}-${suffix}'

// Create a Storage Account for Audit Logs
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

// Create a Log Analytics Workspace
resource loganalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: audit_loganalytics_uniquename
  location: location
  tags: {
    CostCentre: cost_centre_tag
    Owner: owner_tag
    SME: sme_tag
    }
  identity: {type: 'SystemAssigned'}
  properties: {
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    retentionInDays: 30
    sku: {name: 'PerGB2018'}
  }
}

// Role Assignment

@description('This is the built-in Storage Blob Data Reader role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-blob-data-reader')
resource storageBlobDataReaderRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
}

resource grant_purview_sbr_role 'Microsoft.Authorization/roleAssignments@2022-04-01' = if(enable_purview) {
  name: guid(resourceGroup().id,storageAccount.id,storageBlobDataReaderRoleDefinition.id)
  scope: storageAccount
  properties:{
    principalType: 'ServicePrincipal'
    principalId: purview_resource.identity.principalId
    roleDefinitionId: storageBlobDataReaderRoleDefinition.id
  }
}

output audit_storage_uniquename string = audit_storage_uniquename
