// Parameters
@description('Location where resources will be deployed. Defaults to resource group location')
param location string = resourceGroup().location

@description('Cost Centre tag that will be applied to all resources in this deployment')
param cost_centre_tag string

@description('System Owner tag that will be applied to all resources in this deployment')
param owner_tag string

@description('Subject Matter Expert (SME) tag that will be applied to all resources in this deployment')
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

@description('Datalake containers')
param synapse_datalake_containers array =[
  'raw-bronze'
  'curated-silver'
  'curated-gold'
  'drop-zone'
]

@description('Key Vault name')
param dataplatform_keyvault_name string

@description('SQL Administrator User Name')
@secure()
param sqladmin_username string

@description('SQL Administrator password')
@secure()
param sqladmin_password string

@description('Dedicated SQL Pool Name')
param synapse_sqlpool_name string

@description('Dedicated SQL Pool Name')
@allowed([
  'DW100c'
  'DW200c'
  'DW300c'
  'DW400c'
  'DW500c'
  'DW1000c'
  'DW1500c'
  'DW2000c'
  'DW2500c'
  'DW3000c'
  ])
param sqlpool_sku string = 'DW100c'

@description('Synapse Spark Pool dictionary object')
param spark_pools object ={

  pool1:{
    name: 'smallMO'
    maxNodeCount: 4
    minNodeCount: 3
    nodeSize: 'Small'
    nodeSizeFamily: 'MemoryOptimized'
    sparkVersion: '3.4'
  }
  pool2:{
    name: 'mediumMO'
    maxNodeCount: 8
    minNodeCount: 4
    nodeSize: 'Medium'
    nodeSizeFamily: 'MemoryOptimized'
    sparkVersion: '3.4'
  }
  pool3:{
    name: 'largeMO'
    maxNodeCount: 12
    minNodeCount: 6
    nodeSize: 'Large'
    nodeSizeFamily: 'MemoryOptimized'
    sparkVersion: '3.4'
  }
  pool4:{
    name: 'xlargeMO'
    maxNodeCount: 16
    minNodeCount: 8
    nodeSize: 'XLarge'
    nodeSizeFamily: 'MemoryOptimized'
    sparkVersion: '3.4'
  }
  pool5:{
    name: 'xxlargeMO'
    maxNodeCount: 24
    minNodeCount: 12
    nodeSize: 'XXLarge'
    nodeSizeFamily: 'MemoryOptimized'
    sparkVersion: '3.4'
  }
  // pool6:{
  //   name: 'smallGPU'
  //   maxNodeCount: 4
  //   minNodeCount: 3
  //   nodeSize: 'Small'
  //   nodeSizeFamily: 'HardwareAcceleratedGPU'
  //   sparkVersion: '3.4'
  // }
  // pool7:{
  //   name: 'mediumGPU'
  //   maxNodeCount: 8
  //   minNodeCount: 4
  //   nodeSize: 'Medium'
  //   nodeSizeFamily: 'HardwareAcceleratedGPU'
  //   sparkVersion: '3.4'
  // }
  // pool8:{
  //   name: 'largeGPU'
  //   maxNodeCount: 12
  //   minNodeCount: 6
  //   nodeSize: 'Large'
  //   nodeSizeFamily: 'HardwareAcceleratedGPU'
  //   sparkVersion: '3.4'  
  // }
  // pool9:{
  //   name: 'xlargeGPU'
  //   maxNodeCount: 16
  //   minNodeCount: 8
  //   nodeSize: 'XLarge'
  //   nodeSizeFamily: 'HardwareAcceleratedGPU'
  //   sparkVersion: '3.4' 
  // }
}

@description('Flag to indicate whether to enable integration of data platform resources with either an existing or new Purview resource')
param enable_purview bool

@description('Resource Name of new or existing Purview Account. Specify a resource name if create_purview=true or enable_purview=true')
param purview_resource object

@description('Resource id of Purview that will be linked to this Synapse Workspace')
param purview_resourceid string 

@description('Synapse Workspace Administrator Group ObjectID/SID')
param synapse_workspace_admin_sid string

@description('Flag to indicate whether to enable Git repository')
param enable_git bool = false

@description('GitHub Account when Git repository is enabled)')
param git_account string

@description('GitHub Repository when Git enabled)')
param git_repo string

@description('GitHub collaboration branch when Git enabled)')
param git_collaboration_branch string = 'main'

@description('Resource name of audit storage account.')
param audit_storage_name string

@description('Resource group of audit storage account is deployed')
param auditrg string

// Variables
var suffix = uniqueString(resourceGroup().id)
var synapse_workspace_uniquename = '${synapse_workspace_name}-${suffix}'
var managed_synapse_rg_name = 'mrg_${synapse_workspace_uniquename}'
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

//Create datalake containers
resource synapse_storage_container 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = [for container in synapse_datalake_containers :{
  name: '${synapse_storage.name}/default/${container}'
}]

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
        purviewConfiguration:{ purviewResourceId: enable_purview ? purview_resourceid : null }
        sqlAdministratorLogin: sqladmin_username
        sqlAdministratorLoginPassword: sqladmin_password
        workspaceRepositoryConfiguration :{
          accountName: enable_git ? git_account: null
          collaborationBranch: enable_git ? git_collaboration_branch: null
          repositoryName: enable_git ? git_repo: null
          rootFolder: enable_git ? '/': null 
          type: 'WorkspaceGitHubConfiguration'
        }
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

//Synapse Managed Identity SQL Control Settings
resource synapse_sql_mi_config 'Microsoft.Synapse/workspaces/managedIdentitySqlControlSettings@2021-06-01' ={
  name: 'default'
  parent: synapse_workspace
  properties:{ grantSqlControlToManagedIdentity: {desiredState: 'Enabled'} }
}

// Create Key Vault Access Policies
resource dataplatform_keyvault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: dataplatform_keyvault_name
  scope: resourceGroup()

}

resource synapse_keyvault_accesspolicy 'Microsoft.KeyVault/vaults/accessPolicies@2022-07-01' = {
  name: 'add'
  parent: dataplatform_keyvault
  properties: {
    accessPolicies: [
      { tenantId: subscription().tenantId
        objectId: synapse_workspace.identity.principalId
        permissions: { secrets:  ['list','get']}

      }
    ]
  }
}

// Create Synapse Workspace administrator 
resource synapse_workspace_admin 'Microsoft.Synapse/workspaces/administrators@2021-06-01' ={
  name: 'activeDirectory'
  parent: synapse_workspace
  properties:{
    administratorType: 'ActiveDirectory'
    sid: synapse_workspace_admin_sid
    tenantId: subscription().tenantId
  }
}

// Create Dedicated SQL Pool
resource synapse_sqlpool_dwh 'Microsoft.Synapse/workspaces/sqlPools@2021-06-01' = {
  name: synapse_sqlpool_name
  location: location
  parent: synapse_workspace
  tags: {
    CostCentre: cost_centre_tag
    Owner: owner_tag
    SME: sme_tag
  }
  sku:{ name: sqlpool_sku  }
}

// Enable Transparent Data Encryption
resource synapse_tde 'Microsoft.Synapse/workspaces/sqlPools/transparentDataEncryption@2021-06-01' = {
  name: 'current'
  parent: synapse_sqlpool_dwh
  properties: {
    status: 'Enabled'
  }
}

//Create Spark Pool
resource synapse_spark_pool 'Microsoft.Synapse/workspaces/bigDataPools@2021-06-01' = [for spark_pool in items(spark_pools):{
  name: spark_pool.value.name
  location: location
  parent: synapse_workspace
  tags: {
    CostCentre: cost_centre_tag
    Owner: owner_tag
    SME: sme_tag
  }
  properties: {
    autoPause: {
      delayInMinutes: 10
      enabled: true
    }
    autoScale: {
      enabled: true
      maxNodeCount: spark_pool.value.maxNodeCount
      minNodeCount: spark_pool.value.minNodeCount
    }
    nodeSize: spark_pool.value.nodeSize
    nodeSizeFamily: spark_pool.value.nodeSizeFamily
    sparkVersion: spark_pool.value.sparkVersion
  }
}]

//Get Reference to audit storage account
resource audit_storage_account 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: audit_storage_name
  scope: resourceGroup(auditrg)
}

//Enable Audit
resource symbolicname 'Microsoft.Synapse/workspaces/extendedAuditingSettings@2021-06-01' = {
  name: 'default'
  parent: synapse_workspace
  properties: {
    auditActionsAndGroups: [ 'BATCH_COMPLETED_GROUP','SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP','FAILED_DATABASE_AUTHENTICATION_GROUP']
    isAzureMonitorTargetEnabled: true
    isDevopsAuditEnabled: true
    isStorageSecondaryKeyInUse: false
    retentionDays: 90
    state: 'Enabled'
    storageAccountAccessKey: audit_storage_account.listKeys().keys[0].value 
    storageAccountSubscriptionId: subscription().subscriptionId
    storageEndpoint: audit_storage_account.properties.primaryEndpoints.blob
  }
}

// Role Assignment
@description('This is the built-in Contributor role. See https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#contributor')
resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

@description('This is the built-in Reader role. See https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#contributor')
resource readerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
}

@description('This is the built-in Storage Blob Data Reader role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-blob-data-reader')
resource storageBlobDataReaderRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
}

@description('This is the built-in Storage Blob Data Contributor role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor')
resource storageBlobDataContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}


// Grant Purview access to Synapse

resource grant_purview_reader_role 'Microsoft.Authorization/roleAssignments@2022-04-01' = if(enable_purview) {
  name: guid(resourceGroup().id,synapse_workspace.name,readerRoleDefinition.id)
  scope: synapse_workspace
  properties:{
    principalType: 'ServicePrincipal'
    principalId: purview_resource.identity.principalId
    roleDefinitionId: readerRoleDefinition.id
  }
}


resource grant_purview_sbc_role 'Microsoft.Authorization/roleAssignments@2022-04-01' = if(enable_purview) {
  name: guid(resourceGroup().id,synapse_storage.id,storageBlobDataContributorRoleDefinition.id)
  scope: synapse_storage
  properties:{
    principalType: 'ServicePrincipal'
    principalId: purview_resource.identity.principalId
    roleDefinitionId: storageBlobDataContributorRoleDefinition.id
  }
}

// Grant Synapse Storage Blob Data Contributor role to Datalake
resource grant_synapse_sbdc_role 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id,synapse_storage.name,storageBlobDataContributorRoleDefinition.id)
  scope: synapse_storage
  properties:{
    principalType: 'ServicePrincipal'
    principalId: synapse_workspace.identity.principalId
    roleDefinitionId: storageBlobDataContributorRoleDefinition.id
  }
}

output keyvault_name string = dataplatform_keyvault.name
output synapse_storage_name string = synapse_storage.name
