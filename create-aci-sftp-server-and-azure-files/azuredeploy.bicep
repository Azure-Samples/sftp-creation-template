@allowed([
  'Standard_LRS'
  'Standard_ZRS'
  'Standard_GRS'
])
@description('Storage account type')
param storageAccountType string = 'Standard_LRS'

@description('Prefix for new storage account')
param storageAccountPrefix string = 'sftpstg'

@description('Name of file share to be created')
param fileShareName string = 'sftpfileshare'

@description('Username to use for SFTP access')
param sftpUser string = 'sftp'

@secure()
@description('Password to use for SFTP access')
param sftpPassword string

@description('Primary location for resources')
param location string = resourceGroup().location

@description('DNS label for container group')
param containerGroupDNSLabel string = uniqueString(resourceGroup().id, deployment().name)

var sftpContainerName = 'sftp'
var sftpContainerGroupName = 'sftp-group'
var sftpContainerImage = 'atmoz/sftp:debian'
var sftpEnvVariable = '${sftpUser}:${sftpPassword}:1001'
var storageAccountName = take(toLower('${storageAccountPrefix}${uniqueString(resourceGroup().id)}'), 24) //storage account must be =< 24 characters

resource stgacct 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku:{
    name: storageAccountType
  }
}

resource fileshare 'Microsoft.Storage/storageAccounts/fileServices/shares@2019-06-01' = {
  name: toLower('${stgacct.name}/default/${fileShareName}')
}

resource containergroup 'Microsoft.ContainerInstance/containerGroups@2019-12-01' = {
  name: sftpContainerGroupName
  location: location
  properties: {
    containers: [
      {
        name: sftpContainerName
        properties: {
          image: sftpContainerImage
          environmentVariables: [
            {
              name: 'SFTP_USERS'
              secureValue: sftpEnvVariable
            }
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 1
            }
          }
          ports:[
            {
              port: 22
              protocol: 'TCP'
            }
          ]
          volumeMounts: [
            {
              mountPath: '/home/${sftpUser}/upload'
              name: 'sftpvolume'
              readOnly: false
            }
          ]
        }
      }
    ]

    osType:'Linux'
    ipAddress: {
      type: 'Public'
      ports:[
        {
          port: 22
          protocol:'TCP'
        }
      ]
      dnsNameLabel: containerGroupDNSLabel
    }
    restartPolicy: 'OnFailure'
    volumes: [
      {
        name: 'sftpvolume'
        azureFile:{
          readOnly: false
          shareName: fileShareName
          storageAccountName: stgacct.name
          storageAccountKey: listKeys(stgacct.id, '2019-06-01').keys[0].value
        }
      }
    ]
  }
}

output containerDNSLabel string = '${containergroup.properties.ipAddress.dnsNameLabel}.${containergroup.location}.azurecontainer.io'
