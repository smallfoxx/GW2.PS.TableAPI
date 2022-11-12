function Format-GW2SearchString {
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline, Mandatory)]
        [string]$InputObject
    )

    Process {
    $SearchString = $InputObject -replace "[\*\?]", "%"
    If ($SearchString -notmatch "[%""]") {
        $SearchString = "%$($SearchString)%"
    }
    else {
        If ($SearchString -match "^(?<a>[^%""])(?<m>.*)") {
            $SearchMatch = $Matches
            $SearchString = ""
            If ($SearchMatch.a) {
                $SearchString += """{0}" -f $SearchMatch.a
            }
            If ($SearchMatch.m) {
                $SearchString += $SearchMatch.m
            }
        }
        If ($SearchString -match "(?<m>.*)(?<z>[^%""])$") {
            $SearchMatch = $Matches
            $SearchString = ""
            If ($SearchMatch.m) {
                $SearchString += $SearchMatch.m
            }
            If ($SearchMatch.z) {
                $SearchString += "{0}""" -f $SearchMatch.z
            }
        }
    }
    $SearchString
}
}

Function Find-GW2DBItem {
    <#
    .SYNOPSIS
    Search for items from Guild Wars 2 API by name
    #>
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline,Mandatory)]
        [string]$Name
    )
    DynamicParam {
        CommonGW2APIParameters
    }
    Begin {
        $Connected = Connect-GW2LiteDB -PassThru
    }
    Process {
        $APIEndpoint = "items"

        $Name = $Name | Format-GW2SearchString
        
        Get-GW2DBEntryByQuery -CollectionName $APIEndpoint -QueryString "`$.name like '$Name'" @PSBoundParameters
    }
    End {
        If ($Connected) { Disconnect-GW2LiteDB }
    }
}
    
