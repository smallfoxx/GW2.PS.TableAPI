Function New-GW2TableCollection {
    param(
        [parameter(Mandatory)]
        [string]$CollectionName,
        [string[]]$DefaultIndex = @('Id')
    )

    If ($CollectionName -eq 'items') { $DefaultIndex += @('default_skin','name') }
    $Collection = Get-GW2DBCollection -CollectionName $CollectionName
    ForEach ($Index in $DefaultIndex) {
        $Collection.EnsureIndex($Index)
    }
    Write-Output $Collection 
}

Function Get-GW2DBCollection {
    param(
        [parameter(Mandatory)]
        [string]$CollectionName
    )

    $DB = Get-GW2LiteDB
    $DB.GetCollection($CollectionName)

}

Function Test-GW2DBCollection {
    param(
        [parameter(Mandatory)]
        [string]$CollectionName
    )

    $DB = Get-GW2LiteDB
    Write-Output ([bool]($DB.CollectionExists($CollectionName)))

}

Function Get-GW2DBMapper {

    [LiteDB.BSONMapper]::New()

}

Function ConvertTo-GW2DBDocument {
    [OutputType('LiteDB.BsonDocument')]
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline)]
        $InputObject
    )

    Begin {
        $BSONMapper = [LiteDB.BSONMapper]::New()
    }
    Process {
        If ($InputObject) {
            [LiteDB.BsonDocument]$result = ($BSONMapper.ToDocument($InputObject))
            return $result
        }
    }
}

Function Format-GW2DBDocumentValue {
    param($Value)
    $ConversionAttempts = 0

    While (($value -match "^(([""\{])|(\[[^&]))") -and ($ConversionAttempts -lt 5) ) {
        try {
            $ConversionAttempts++
            Write-Debug "attempting [$ConversionAttempts] to convert [ $value ]"
            $Value = $Value | ConvertFrom-Json -ErrorAction Stop
        } catch {
            Write-Debug "Failed to convert [ $value ] after [ $ConversionAttempts ] attempts"
            $ConversionAttempts++
        }
    }
    $Value

}

Function ConvertFrom-GW2DBDocumentStatic {
<#
.SYNOPSIS
Removes JSON obfuscation of BSON Document properties and builds array into standard PSCustomObject
#>
param($Document)

    $result = @{}
    ForEach ($Property in $Document) {
        $result.($Property.key) = Format-GW2DBDocumentValue -Value ($Property.Value)
    }
    [PSCustomObject]$result

}

Function ConvertFrom-GW2DBDocument {
<#
.SYNOPSIS
Removes JSON obfuscation of BSON Document properties and builds array into standard PSCustomObject
#>
    param(
        [parameter(ValueFromPipeline,Mandatory)]
        $Document)

Process {
    $result = [PSCustomObject]@{
        "Document" = $Document
    }

    ForEach ($Property in $Document) {
        Invoke-Expression @"
`$result | Add-Member ScriptProperty '$($Property.Key)' { 
    `$Property = `$this.Document | Where-Object { `$_.Key -eq '$($Property.Key)'  }
    If (`$Property){
        Format-GW2DBDocumentValue -Value `$Property.Value
    }
} -Force
"@ 
#Invoke-Expression @"
#`$result | Add-Member NoteProperty '$($Property.Key)' ($($Property.Value)) -Force
#"@
    }
    [PSCustomObject]$result

}
}

Function Add-GW2DBEntry {
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline)]
        [PSCustomObject]$InputObject,
        [parameter(Mandatory)]
        [string]$CollectionName,
        [switch]$CheckExist,
        [switch]$PassThru
    )
    Begin {
        #Ensure that if they past an endpoint name, we ensure its a proper collection name before we get the collection
        $CollectionName = Get-GW2DBCollectionName -EndPointName $CollectionName
        If (-not (Test-GW2DBCollection -CollectionName $CollectionName)) {
            $CollectionCreation = New-GW2DBCollection -CollectionName $CollectionName
        }
        $Collection = Get-GW2DBCollection -CollectionName $CollectionName
        $BSONMapper = Get-GW2DBMapper
        $Documents = [System.Collections.ArrayList]@()
    }
    Process {
        #$doc = [LiteDB.BsonDocument]::New()
        $doc = $BSONMapper.ToDocument(@{'id' = $InputObject.Id })
        ForEach ($prop in ($InputObject | Get-Member -MemberType NoteProperty )) { #| select -first $count)) {
            If (-not ([string]::IsNullOrEmpty( $InputObject.($prop.Name)))) { #.length -gt 0) {
                Write-Debug "$($Collection.name): $($prop.name) => '$($InputObject.($prop.Name))' [$($InputObject.($prop.Name).length)]"
                $doc[$prop.name] = $InputObject.($prop.Name) | ConvertTo-Json -Depth 10  # $BSONMapper.ToDocument(
            }
        }
        Write-Debug "$($Collection.name): $($doc['id']) => $($doc['name'])"
        If ($CheckExist) {
            $Found = $Collection.FindOne("`$.Id = '$($doc['id'])'")
            If ($Found) {
                $doc['_id']=$Found['_id']
                $UpsertResult = $Collection.Update($doc) #($BSONMapper.ToDocument($InputObject)))
            } else {
                $Documents.Add($doc)
                #$UpsertResult = $Collection.Insert($doc) #($BSONMapper.ToDocument($InputObject)))
            }
        } else {
            $Documents.Add($doc)
            #$UpsertResult = $Collection.Insert($doc) #($BSONMapper.ToDocument($InputObject)))
        }
        Write-Debug "Upsert result: $UpsertResult"
        If ($PassThru) { ConvertFrom-GW2DBDocument -Document $doc }
    }
    End {
        If ($Documents.count -gt 0) {
            $UpsertResult = $Collection.InsertBulk($Documents, $Documents.Count)
            Write-Debug "Upsert result: $UpsertResult"
        }
    }
}

Function Get-GW2DBEntryByQuery {
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$QueryString,
        [parameter(Mandatory)]
        [string]$CollectionName,
        [switch]$SingleResult,
        [parameter(ValueFromRemainingArguments)]
        $RemaingArgs
    )

    Begin {
        $Connected = Connect-GW2LiteDB -PassThru

        #Ensure that if they past an endpoint name, we ensure its a proper collection name before we get the collection
        $CollectionName = Get-GW2DBCollectionName -EndPointName $CollectionName
        If (-not (Test-GW2DBCollection -CollectionName $CollectionName)) {
            $CollectionCreation = New-GW2DBCollection -CollectionName $CollectionName
        }
        $Collection = Get-GW2DBCollection -CollectionName $CollectionName
    }

    Process {
        If ($SingleResult) {
            $Documents = $Collection.FindOne($QueryString)
        } else {
            $Documents = $Collection.Find($QueryString)
        }
        $Results = $Documents | ForEach-Object { ConvertFrom-GW2DBDocument -Document $_ }
        return $results
    }

    End {
        If ($Connected) { Disconnect-GW2LiteDB }
    }
}

Function Find-GW2DBMissingEntries {
    param(
        $Reference,
        $Difference
    )
    
    $CleanReference = $Reference -split ',' | ForEach-Object { $_ -replace "^'(.*)'$","`$1" }
    $CleanDiff      = $Difference -split ',' | ForEach-Object { $_ -replace "^'(.*)'$","`$1" }

    $CleanDiff | Where-Object { $_ -notin $CleanReference } | Where-Object { $_ }

}

Function ConvertTo-GW2DBQueryArray {
    param(
        [parameter(Mandatory)]
        $Entries
    )

    $FormatEntries = ForEach ( $E in ($Entries -split ",")) {
        If ($e -match "^'[^']*'$") { 
            $e
        } else {
            "'$e'" 
        }
    }

    ("[ {0} ]" -f ($FormatEntries -join ','))
}

Function Get-GW2DBEntry {
    [cmdletbinding(DefaultParameterSetName="OnlyID")]
    param(
        [parameter(ValueFromPipeline,ValueFromPipelineByPropertyName,ParameterSetName="AllEntries")]
        [parameter(ValueFromPipeline,ValueFromPipelineByPropertyName,ParameterSetName="OnlyID")]
        [string[]]$Id,
        [parameter(ValueFromPipeline,ValueFromPipelineByPropertyName,ParameterSetName="PropertyHashTable",Mandatory)]
        [hashtable]$PropertyValues,
        [parameter(ParameterSetName="AllEntries",Mandatory)]
        [switch]$All,
        [parameter(Mandatory)]
        [string]$CollectionName,
        [switch]$SkipOnlineLookup,
        [switch]$DkipDocumentConversion

    )
    Begin {
        #Ensure that if they past an endpoint name, we ensure its a proper collection name before we get the collection
        $CollectionName = Get-GW2DBCollectionName -EndPointName $CollectionName
        If (-not (Test-GW2DBCollection -CollectionName $CollectionName)) {
            $CollectionCreation = New-GW2DBCollection -CollectionName $CollectionName
        }
        $Collection = Get-GW2DBCollection -CollectionName $CollectionName
        $MissingIds=@()
    }
    Process {
        switch ($PSCmdlet.ParameterSetName) {
            "AllEntries" {
                Write-Information "Looking for $($Id.count) IDs"
                $AllDocs = $Collection.FindAll() 
                If ($SkipDocumentConversion) {
                    $AllDocs
                } else {
                    $AllEntries = $AllDocs | ForEach-Object { ConvertFrom-GW2DBDocument -Document $_ }
                    If (($Id.Count -gt 0) -and ($AllEntries.Count -gt 0)) {
                        $IdsNotInResults = Find-GW2DBMissingEntries -Reference ($AllEntries.Ids) -Difference $Id #-Comparison ($AllEntries.Ids)
                        $MissingIds += @($IdsNotInResults)
                    }
                    $AllEntries
                }

            }
            "OnlyID" {
                Write-Debug "Database query of $CollectionName for IDs = $ID"
                If ($ID -match ","){
                    $QueryArray = ConvertTo-GW2DBQueryArray -Entries $Id

                    Write-Debug "Querying $COllectionName for an array $QueryArray"

                    $Documents = $Collection.Find("`$.Id in $QueryArray")

                    If ($Documents) {
                        Write-Debug "Converting documents..."
                        If ($SkipDocumentConversion) {
                            $Documents
                        } else {
                            $Results = $Documents | ForEach-Object { ConvertFrom-GW2DBDocument -Document $_ }
                            $IdsNotInResults = Find-GW2DBMissingEntries -Reference ($Results.Id) -Difference $Id 

                            $MissingIds += @($IdsNotInResults)
                            $Results
                        }
                    }
                } else {
                    $Document = $Collection.FindOne("`$.Id = '$Id'")
                    If ($Document) {
                        ConvertFrom-GW2DBDocument -Document $Document
                    } else {
                        $MissingIds += @($Id)
                    }
                }

            }
            default {
                $QueryElements=[System.Collections.ArrayList]@()
                ForEach ($Property in $PropertyValues.Keys) {
                    $QueryElements.Add(("`$.{0} = '{1}'" -f $Property,$PropertyValues.$Property))
                }
                $FullQuery = $QueryElements -join " and "
                Write-Debug "Attempting to query $CollectionName for $FullQuery"
                $Document = $Collection.FindOne($FullQuery)
                If ($SkipDocumentConversion) {
                    $Document
                } else {
                    ConvertFrom-GW2DBDocument -Document $Document
                }
            }
        }
    }
    End {
        If (($MissingIds.Count -gt 0) -and (-not $SkipOnlineLookup)) {
            Write-Debug "Couldn't find $($MissingIds.count) IDs in Database; looking up online ($($MissingIds -join ','))"
            $APIValue = Get-GW2DBAPIValue -CollectionName $CollectionName
            $MissingEntries = Get-GW2APIValue -APIValue $APIValue -APIParams @{ 'ids' = ($MissingIds -join ',') } -UseCache:$false -UseDB:$false
            $MissingEntries | Add-GW2DBEntry -CollectionName $CollectionName -PassThru
        }
    }
}

Function Get-GW2DBCollectionName {
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$EndPointName)

    Process {
        $EndpointName -replace "[\\/]","_"
    }
}

Function Get-GW2DBAPIValue {
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$CollectionName)

    Process {
        $CollectionName -replace "_","/"
    }
}

Function Get-GW2DBValue {
    [cmdletbinding()]
    param(
        [string]$APIValue,
        [securestring]$SecureAPIKey,
        [hashtable]$APIParams
    )

    Begin {
        $CollectionName = $APIValue | Get-GW2DBCollectionName
        $ConnectedInSession = Connect-GW2LiteDB -PassThru
    }

    Process {
        If ($APIParams.Ids) {
            Get-GW2DBEntry -CollectionName $CollectionName -Id $APIParams.Ids 
        } elseIf ($APIParams.count -gt 0) {
            Get-GW2DBEntry -CollectionName $CollectionName -PropertyValues $APIParams 
        } else {
            $WebResults = Get-GW2APIValue -APIValue $APIValue -SecureAPIKey $SecureAPIKey -APIParams $APIParams -UseCache:$false -UseDB:$false
            $WebResults
        }
    }

    ENd {
        If ($ConnectedInSession) {
            Disconnect-GW2LiteDB
        }
    }

}
