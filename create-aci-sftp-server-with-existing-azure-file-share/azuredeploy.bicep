@description('Resource group for existing storage account')
param existingStorageAccountResourceGroupName string

@description('Name of existing storage account')
param existingStorageAccountName string

@description('Name of existing file share to be mounted')
param existingFileShareName string

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

resource stgacct 'Microsoft.Storage/storageAccounts@2019-06-01' existing = {
  name: existingStorageAccountName
  scope: resourceGroup(existingStorageAccountResourceGroupName)
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
          shareName: existingFileShareName
          storageAccountName: stgacct.name
          storageAccountKey: listKeys(stgacct.id, '2019-06-01').keys[0].value
        }
      }
    ]
  }
}

output containerDNSLabel string = '${containergroup.properties.ipAddress.dnsNameLabel}.${containergroup.location}.azurecontainer.io'
