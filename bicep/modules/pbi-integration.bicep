// Parameters
@description('Location where resources will be deployed. Defaults to PBI Tenant resource group location')
param location string = resourceGroup().location

@description('Cost Centre tag that will be applied to all resources in this deployment')
param cost_centre_tag string

@description('System Owner tag that will be applied to all resources in this deployment')
param owner_tag string

@description('Subject Matter Expert (SME) tag that will be applied to all resources in this deployment')
param sme_tag string

@description('Power BI Datalake name')
param pbi_datalake_name string

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
param pbi_datalake_sku string ='Standard_LRS'

@description('Flag to indicate whether to enable integration of data platform resources with either an existing or new Purview resource')
param enable_purview bool

@description('Resource Name of new or existing Purview Account. Specify a resource name if create_purview=true or enable_purview=true')
param purview_resource object

@description('Power BI Administrator ObjectID/SID')
param pbi_admin_sid string

// Variables
var suffix = uniqueString(resourceGroup().id)
var pbi_datalake_uniquename = substring('${pbi_datalake_name}${suffix}',0,24)

// Create datalake linked to synapse workspace
resource pbi_storage 'Microsoft.Storage/storageAccounts@2022-09-01' ={
  name: pbi_datalake_uniquename
  location: location
  tags: {
        CostCentre: cost_centre_tag
        Owner: owner_tag
        SME: sme_tag
        }
  sku: {name: pbi_datalake_sku}
  kind:'StorageV2'
  identity: {type: 'SystemAssigned'}
  properties:{
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    isHnsEnabled: true
    minimumTlsVersion: 'TLS1_2'
  }
} 


// Role Assignment
@description('This is the built-in Owner role. See https://docs.microsoft.com/azure/role-based-access-control/built-in-roles')
resource ownerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
}

@description('This is the built-in Storage Blob Data Owner role. See https://docs.microsoft.com/azure/role-based-access-control/built-in-roles')
resource storageBlobDataOwnerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
}

@description('This is the built-in Storage Blob Reader Owner role. See https://docs.microsoft.com/azure/role-based-access-control/built-in-roles')
resource storageBlobDataReaderRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
}

// @description('This is the built-in Contributor role. See https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#contributor')
// resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
//   scope: subscription()
//   name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
// }

@description('This is the built-in Reader role. See https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#contributor')
resource readerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
}

// Grant Power BI Admin Owner, Storage Blob Owner and Storage Blob Reader role to Datalake
resource grant_pbi_dls_owner_role 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id,pbi_storage.name,ownerRoleDefinition.id)
  scope: pbi_storage
  properties:{
    principalType: 'User'
    principalId: pbi_admin_sid
    roleDefinitionId: ownerRoleDefinition.id
  }
}

resource grant_pbi_dls_blobowner_role 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id,pbi_storage.name,storageBlobDataOwnerRoleDefinition.id)
  scope: pbi_storage
  properties:{
    principalType:  'User'
    principalId: pbi_admin_sid
    roleDefinitionId: storageBlobDataOwnerRoleDefinition.id
  }
}

resource grant_pbi_dls_blobreader_role 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id,pbi_storage.name,storageBlobDataReaderRoleDefinition.id)
  scope: pbi_storage
  properties:{
    principalType:  'User'
    principalId: pbi_admin_sid
    roleDefinitionId: storageBlobDataReaderRoleDefinition.id
  }
}

// Grant Purview reader roles to Datalake
resource grant_purview_dls_role 'Microsoft.Authorization/roleAssignments@2022-04-01' = if(enable_purview) {
  name: guid(resourceGroup().id,pbi_storage.name,readerRoleDefinition.id)
  scope: pbi_storage
  properties:{
    principalType: 'ServicePrincipal'
    principalId: purview_resource.identity.principalId
    roleDefinitionId: readerRoleDefinition.id
  }
}

