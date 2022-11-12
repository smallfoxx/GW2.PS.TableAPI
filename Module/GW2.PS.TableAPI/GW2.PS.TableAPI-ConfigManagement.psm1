Function New-GW2TableAPISettings {
    param([string]$AccountName="",
        [string]$AccountKey="")

    $Settings = [PSCustomObject]@{
        "AccountName" = $AccountName
        "AccountKey" = $AccountKey
        "Prefix" = "GW2.PS"
        "MinTouch" = 1440
        "MaxAge" = 2628000
        "UseTable" = $true
    }
    $Settings | Add-Member ScriptProperty ConnectionString {
        "DefaultEndpointsProtocol=https;AccountName={0};AccountKey={1};TableEndpoint=https://{0}.table.cosmos.azure.com:443/;" -f $this.AccountName,$this.AccountKey
    }

    $Settings
}

Function Set-GW2TableAccount {
    param(
        [parameter(ValueFromPipelineByPropertyName,Mandatory)]
        [string]$AccountName,
        [string]$AccountKey
    )

    Set-GW2ConfigValue -Section Table -Name 'AccountName' -Value $AccountName
    If ($AccountKey) {
        Set-GW2ConfigValue -Section Table -Name 'AccountKey' -Value $AccountKey
    }
}

Function Set-GW2UseDB {
    param([switch]$Disable)

    Set-GW2ConfigValue -Section Table -Name 'UseTable' -Value (-not $Disable)
}

Function Get-GW2TableConnectString {
   param(
    $Name = (Get-GW2ConfigValue -Section Table -Name 'AccountName'),
    $Key = (Get-GW2ConfigValue -Section Table -Name 'AccountKey')
  )

   "DefaultEndpointsProtocol=https;AccountName={0};AccountKey={1};TableEndpoint=https://{0}.table.cosmos.azure.com:443/;" -f $Name,$Key

}