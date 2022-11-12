Function Import-GW2EndpointData {
    <#
    .SYNOPSIS
    Get a listing of all the endpoints that are static and should cause a problem to be cached.
    #>
    [cmdletbinding(DefaultParameterSetName="OnlyCacheable")]
    param(
        [parameter(ParameterSetName="OnlyCacheable")]
        [switch]$Cacheable,
        [parameter(ParameterSetName="AllEndpoints",Mandatory)]
        [switch]$All,
        [parameter(ParameterSetName="DynamicContent",Mandatory)]
        [switch]$NonCached,
        [parameter(ParameterSetName="CoreContent",Mandatory)]
        [switch]$Core,
        [parameter(ParameterSetName="SpecificEndpoints",Mandatory)]
        [string]$Endpoint
    )
    DynamicParam {
        CommonGW2APIParameters
    }
    Begin {
        $Connected = Connect-GW2LiteDB -PassThru
    }
    Process {
        Switch ($PSCmdlet.ParameterSetName) {
            'AllEndPoints' {
                $EndPoints = Get-GW2APIEndpoint -Detail
            }
            'DynamicContent' {
                $EndPoints = Get-GW2APIEndpointNoCache -Detail
            }
            'CoreContent' {
                $EndPoints = @("skins","items") | ForEach-Object { Get-GW2APIEndpoint -EPName $_ -Detail }
            }
            'SpecificEndpoints' {
                $EndPoints = $Endpoint -split ',' | ForEach-Object { Get-GW2APIEndpoint -EPName $_ -Detail }
            }
            default {
                $EndPoints = Get-GW2APIEndpointCacheable -Detail
            }
        }
        ForEach ($EP in ($EndPoints | Where-Object { $_.Enabled -and -not ($_.IDRequired) })) {
            Write-Host "Getting info for $($EP.name)..." -NoNewline

            $ids = Get-GW2APIValue -APIValue $EP.Name # Invoke-Expression $Command
            Write-Host " ..more details for [$($ids.count)].. " -NoNewline
            $details = $ids | Group-GW2ObjectByCount | ForEach-Object {
                $APIParams = @{ 'ids' = ($_ -join ',') }
                Get-GW2APIValue -APIValue $EP.Name -APIParams $APIParams -Online -UpdateDB
            }

            Write-Host " found [$($details.count)] items!"

        }
    }
    ENd {
        If ($Connected) {
            Disconnect-GW2LiteDB
        }
    }
}

Function Get-GW2DBCollectionCount {
    param(
        [parameter(Mandatory)]
        [string]$CollectionName
    )

    $CollectionName = Get-GW2DBCollectionName -EndPointName $CollectionName
    $Collection = Get-GW2DBCollection -CollectionName $CollectionName
    $Collection.Count()

}

Function Test-GW2DBMinimum {
    param(
        [string[]]$PrimaryCollection=@('items','skins'),
        [switch]$Prompt
    )

    $ValidCollections = $true
    $Connected = Connect-GW2LiteDB -PassThru
    ForEach ($CollectionName in $PrimaryCollection) {
        $ValidCollections = $ValidCollections -and ((Get-GW2DBCollectionCount -CollectionName $CollectionName) -gt 10)
    }

    If ((-not $ValidCollections) -and $Prompt) {
        Write-Host "Minimum local databases have not been cached locally from the API. You can"
        write-Host "import the data to the local database with 'Import-GW2EndpointData'."
        $Response = Read-Host "Go ahead and download the data now from the GW2 API? (y/N) "
        If ($Response -match "^y") {
            Write-Host "Importing core endpoint data..." -ForegroundColor Cyan
            Import-GW2EndpointData -Core -Debug
            If ($PassThru) { $True }
        } else {
            $ValidCollections
        }
    } else {
        $ValidCollections
    }

    If ($Connected) {
        Disconnect-GW2LiteDB
    }
}

