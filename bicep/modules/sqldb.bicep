@description('Name of SQL Server')
param sqlserver_name string

@description('Name of Database')
param database_name string

@description('Azure Location SQL Server')
param location string = resourceGroup().location

@description('Cost Centre tag that will be applied to all resources in this deployment')
param cost_centre_tag string

@description('System Owner tag that will be applied to all resources in this deployment')
param owner_tag string

@description('Subject Matter Expert (SME) tag that will be applied to all resources in this deployment')
param sme_tag string

@description('SQL Server admin user name')
@secure()
param sql_admin_username string

@description('SQL Server admin user name')
@secure()
param sql_admin_password string

@description('AD server admin user name')
@secure()
param ad_admin_username string

@description('SID (object ID) of the server administrator')
@secure()
param ad_admin_sid string

@description('Database SKU name, e.g P3. For valid values, run this CLI az sql db list-editions -l australiaeast -o table')
param database_sku_name string ='GP_S_Gen5_1'

@description('Time in minutes after which database is automatically paused')
param auto_pause_duration int =60


// Variables
var suffix = uniqueString(resourceGroup().id)
var sqlserver_unique_name = '${sqlserver_name}-${suffix}'

// Deploy SQL Server
resource sqlserver 'Microsoft.Sql/servers@2022-05-01-preview' ={
  name: sqlserver_unique_name
  location: location
  tags: {
    CostCentre: cost_centre_tag
    Owner: owner_tag
    SME: sme_tag
    }
  identity:{ type: 'SystemAssigned'}
  properties: {
    administratorLogin: sql_admin_username
    administratorLoginPassword: sql_admin_password
    administrators:{
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: false
      login: ad_admin_username
      sid: ad_admin_sid
      principalType: 'User'
      tenantId: subscription().tenantId
    }
    minimalTlsVersion: '1.2'

  }
}

// Deploy database
resource database 'Microsoft.Sql/servers/databases@2021-11-01' ={
  name: database_name
  location: location
  tags: {
    CostCentre: cost_centre_tag
    Owner: owner_tag
    SME: sme_tag
    }
  sku:{name: database_sku_name}
  parent: sqlserver
  properties: {
    autoPauseDelay:auto_pause_duration
  }
}
