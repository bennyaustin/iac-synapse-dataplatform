// Scope
targetScope = 'subscription'

// Parameters
@description('Resource group where Synapse will be deployed. Resource group will be created if it doesnt exist')
param resourcegroup string= 'rg-synapse-dataplatform'

@description('Resource group location')
param rglocation string = 'australiaeast'

@description('Cost Centre tag that will be applied to all resources in this deployment')
param cost_centre_tag string = 'Jupiter'

@description('System Owner tag that will be applied to all resources in this deployment')
param owner_tag string = 'jupiter@contoso.com'

@description('Subject Matter EXpert (SME) tag that will be applied to all resources in this deployment')
param sme_tag string ='saturn@contoso.com'

@description('Timestamp that will be appendedto the deployment name')
param deployment_suffix string = utcNow()

// Variables
var deployment_name = 'synapse_dataplatform_deployment_${deployment_suffix}'

// Create Resource Group
resource synapse_rg  'Microsoft.Resources/resourceGroups@2022-09-01' = {
 name: resourcegroup 
 location: rglocation
 tags: {
        CostCentre: cost_centre_tag
        Owner: owner_tag
        SME: sme_tag
  }
}

// Deploy dataplatform using module
// Deploys Synapse Analytics Workspace, Datalake, Firewall rules, Keyvault with access policies
module synapse_dp './modules/synapse-dataplatform.bicep' = {
  name: deployment_name
  scope: synapse_rg
  params:{
    location: rglocation
    cost_centre_tag: cost_centre_tag
    owner_tag: owner_tag
    sme_tag: sme_tag
    synapse_workspace_name: 'ba-synapse01'
    synapse_datalake_name: 'badatalake01'
    synapse_datalake_sku: 'Standard_LRS'
    dataplatform_keyvault_name: 'ba-kv01'
    synapse_sqlpool_name: 'dwh01'
    sqlpool_sku: 'DW100c'

  }
  
}
