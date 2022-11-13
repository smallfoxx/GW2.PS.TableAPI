param name string = uniqueString(resourceGroup().id, deployment().name)
param locationName string = 'North Central US'
param location string = toLower(replace(locationName, ' ', ''))
param defaultExperience string = 'Azure Table'
param isZoneRedundant string = 'false'

resource cosmos_table 'Microsoft.DocumentDb/databaseAccounts@2022-08-15-preview' = {
  kind: 'GlobalDocumentDB'
  name: name
  location: location
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        id: '${name}-${location}'
        failoverPriority: 0
        locationName: locationName
      }
    ]
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: 8
        backupStorageRedundancy: 'Geo'
      }
    }
    isVirtualNetworkFilterEnabled: false
    virtualNetworkRules: []
    ipRules: []
    capabilities: [
      {
        name: 'EnableTable'
      }
      {
        name: 'EnableServerless'
      }
    ]
    enableFreeTier: false
    capacity: {
      totalThroughputLimit: 4000
    }
  }
  tags: {
    defaultExperience: defaultExperience
    'hidden-cosmos-mmspecial': ''
  }
}

output db_name string = cosmos_table.name
output db_id string = cosmos_table.id
