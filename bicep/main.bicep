// Scope
targetScope = 'subscription'

// Parameters
@description('Resource group where Synapse will be deployed. Resource group will be created if it doesnt exist')
param dprg string= 'prg-synapse-dataplatform'

@description('Resource group location')
param rglocation string = 'australiaeast'

@description('Cost Centre tag that will be applied to all resources in this deployment')
param cost_centre_tag string = 'Uranus'

@description('System Owner tag that will be applied to all resources in this deployment')
param owner_tag string = 'uranus@contoso.com'

@description('Subject Matter EXpert (SME) tag that will be applied to all resources in this deployment')
param sme_tag string ='neptune@contoso.com'

@description('Timestamp that will be appendedto the deployment name')
param deployment_suffix string = utcNow()

@description('Resource group where Purview will be deployed. Resource group will be created if it doesnt exist')
param purviewrg string= 'rg-datagovernance'

@description('Flag to indicate whether to create a new Purview resource with this data platform deployment')
param create_purview bool = false

@description('Flag to indicate whether to enable integration of data platform resources with either an existing or new Purview resource')
param enable_purview bool = true

@description('Resource Name of new or existing Purview Account. Specify a resource name if create_purview=true or enable_purview=true')
param purview_name string = 'ba-purview01'

@description('Power BI tenant location')
param pbilocation string = 'westus3'

@description('Resource group where audit resources will be deployed. Resource group will be created if it doesnt exist')
param auditrg string= 'rg-audit'


// Variables
var synapse_deployment_name = 'synapse_dataplatform_deployment_${deployment_suffix}'
var purview_deployment_name = 'purview_deployment_${deployment_suffix}'
var pbi_deployment_name = 'pbi_deployment_${deployment_suffix}'
var keyvault_deployment_name = 'keyvault_deployment_${deployment_suffix}'
var controldb_deployment_name = 'controldb_deployment_${deployment_suffix}'
var audit_deployment_name = 'audit_deployment_${deployment_suffix}'

// Create data platform resource group
resource synapse_rg  'Microsoft.Resources/resourceGroups@2022-09-01' = {
 name: dprg 
 location: rglocation
 tags: {
        CostCentre: cost_centre_tag
        Owner: owner_tag
        SME: sme_tag
  }
}


// Create purview resource group
resource purview_rg  'Microsoft.Resources/resourceGroups@2022-09-01' = if (create_purview) {
  name: purviewrg 
  location: rglocation
  tags: {
         CostCentre: cost_centre_tag
         Owner: owner_tag
         SME: sme_tag
   }
 }

 // Create audit resource group
resource audit_rg  'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: auditrg 
  location: rglocation
  tags: {
         CostCentre: cost_centre_tag
         Owner: owner_tag
         SME: sme_tag
   }
 }


 // Deploy Purview using module
module purview './modules/purview.bicep' = if (create_purview || enable_purview) {
  name: purview_deployment_name
  scope: purview_rg
  params:{
    create_purview: create_purview
    purviewrg: purviewrg
    purview_name: purview_name
    location: purview_rg.location
    cost_centre_tag: cost_centre_tag
    owner_tag: owner_tag
    sme_tag: sme_tag
  }
  
}

// Deploy Key Vault with default access policies using module
module kv './modules/keyvault.bicep' = {
  name: keyvault_deployment_name
  scope: synapse_rg
  params:{
     location: synapse_rg.location
     keyvault_name: 'ba-kv01'
     cost_centre_tag: cost_centre_tag
     owner_tag: owner_tag
     sme_tag: sme_tag
  }
}

resource kv_ref 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: kv.outputs.keyvault_name
  scope: synapse_rg
}

//Enable auditing for data platform resources
module audit_integration './modules/audit.bicep' = {
  name: audit_deployment_name
  scope: audit_rg
  params:{
    location: audit_rg.location
    cost_centre_tag: cost_centre_tag
    owner_tag: owner_tag
    sme_tag: sme_tag
    audit_storage_name: 'baauditstorage01'
    audit_storage_sku: 'Standard_LRS'    
  }
  
}

//Deploy Power BI Integrations
module pbi_integration './modules/pbi-integration.bicep' = {
  name: pbi_deployment_name
  scope: synapse_rg
  params:{
    location: pbilocation
    cost_centre_tag: cost_centre_tag
    owner_tag: owner_tag
    sme_tag: sme_tag
    pbi_datalake_name: 'bapbistorage02'
    pbi_datalake_sku: 'Standard_LRS'
    enable_purview: enable_purview
    purview_resource: purview.outputs.purview_resource
    pbi_admin_sid: '427bc8f2-8bf1-441b-8a24-d43e1f53698c' //Replace this with your AD group ID 
  }
  
}


// // Deploy dataplatform using module
// // Deploys the following resources
// // - Synapse Analytics Workspace
// // - Datalake
// // - Dedicated SQL Pool
// // - Spark Pools - small , medium, large, xlarge
// // - Firewall rules
// // - Keyvault with access policies
// // - Synapse link for Purview
module synapse_dp './modules/synapse-dataplatform.bicep' = {
  name: synapse_deployment_name
  scope: synapse_rg
  params:{
    location: synapse_rg.location
    cost_centre_tag: cost_centre_tag
    owner_tag: owner_tag
    sme_tag: sme_tag
    synapse_workspace_name: 'ba-synapse01'
    synapse_datalake_name: 'badatalake01'
    synapse_datalake_sku: 'Standard_LRS'
    sqladmin_username: kv_ref.getSecret('sqlserver-admin-username')
    sqladmin_password: kv_ref.getSecret('sqlserver-admin-password')
    dataplatform_keyvault_name: kv.outputs.keyvault_name
    synapse_sqlpool_name: 'dwh01'
    sqlpool_sku: 'DW100c'
    enable_purview: enable_purview
    purview_resourceid: purview.outputs.purview_resourceid
    purview_resource: purview.outputs.purview_resource
    synapse_workspace_admin_sid: 'c7c5e19c-a8e9-451e-b0a5-7a38a8fce9fe' //Replace this with your AD group ID 
    enable_git: false
    git_account: 'not applicable'
    git_repo: 'not applicable'
    git_collaboration_branch: 'not applicable'    
  }
  
}


//Deploy SQL control DB 
// - SQL Server and control database for ELT framework

resource keyvault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: synapse_dp.outputs.keyvault_name
  scope: synapse_rg
}

module controldb './modules/sqldb.bicep' = {
  name: controldb_deployment_name
  scope: synapse_rg
  params:{
     sqlserver_name: 'ba-sql01'
     database_name: 'controlDB' 
     location: synapse_rg.location
     cost_centre_tag: cost_centre_tag
     owner_tag: owner_tag
     sme_tag: sme_tag
     sql_admin_username: keyvault.getSecret('sqlserver-admin-username')
     sql_admin_password: keyvault.getSecret('sqlserver-admin-password')
     ad_admin_username:  keyvault.getSecret('sqlserver-ad-admin-username')
     ad_admin_sid:  keyvault.getSecret('sqlserver-ad-admin-sid')  
     auto_pause_duration: 60
     database_sku_name: 'GP_S_Gen5_1' 
     enable_purview: enable_purview
     purview_resource: purview.outputs.purview_resource
     audit_storage_name: audit_integration.outputs.audit_storage_uniquename
     auditrg: audit_rg.name
  }
}

