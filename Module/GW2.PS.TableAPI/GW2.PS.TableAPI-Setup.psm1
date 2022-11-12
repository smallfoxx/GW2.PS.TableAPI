Function ConnectToAzure {
    param(
        [string]$Tenant,
        [string]$Subscription
    )

    $Context = Get-AzContext
    $KeepContext = $true
    If ($Context) {
        If ($Tenant) {
            $KeepContext = $KeepContext -and ($Context.Tenant -eq $Tenant)
        }
        If ($Subscription) {
            $KeepContext = $KeepContext -and ($Context.Subscription -eq $Subscription)
        }
    } else {
        $KeepContext = $false
    }

    If ($KeepContext) {
        $Context
    } else {
        $ContextParams = @{}
        If ($Tenant) { $ContextParams.Tenant = $Tenant}
        If ($Subscription) { $ContextParams.Subscription = $Subscription }
        Connect-AzAccount @ContextParams
    }

}
Function Deploy-GW2TableAPI {
    param(
        [string]$Tenant,
        [string]$Subscription,
        [string]$TemplatePath="",
        [string]$ResourceGroupName="GW2Data-RG",
        [string]$Location="northcentralus"
    )

    $Context = ConnectToAzure -Tenant $Tenant -Subscription $Subscription
    If ($Context) {
        try {
            $ResourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
        } catch {
            
        }
        New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName 
    }
}

Function Connect-GW2TableAPI {
    param(
        [string]$AccountName = (Get-GW2ConfigValue -Section 'Table' -Name 'AccountName'),
        [string]$AccountKey = (Get-GW2ConfigValue -Section 'Table' -Name 'AccountKey'),
        [switch]$PassThru
    )

    Import-Module Az.Storage

    $connectionString = Get-GW2TableConnectString -Name $AccountName -Key $AccountKey
    $storageAccount = [Microsoft.Azure.Cosmos.Table.CloudStorageAccount]::Parse($connectionString);
    $script:GW2PSTableClient = [Microsoft.Azure.Cosmos.Table.CloudTableClient]::new($storageAccount.TableEndpoint,$storageAccount.Credentials)

    If ($PassThru) { Test-GW2TableAPI }

}

Function Disconnect-GW2LiteDB {
    param()

    if (Test-GW2TableAPI) {
        Remove-Variable -Scope Script -Name 'GW2PSTableClient'
    }
}

Function Test-GW2TableAPI {

    If ($script:GW2PSTableClient) {
        $active = $true
        try {
            $null = $script:GW2PSTableClient.ListTables()
        }
        catch {
            $active = $false
        }
    }
    else {
        $active = $false
    }

    $active
}

Function Get-GW2TableAPIClient {
    param()

    $script:GW2PSTableClient

}

Set-Alias -Name Install-GW2DB -Value Install-GW2LiteDB
