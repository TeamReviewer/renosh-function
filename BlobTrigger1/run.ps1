# Input bindings are passed in via param block.
param([byte[]] $InputBlob, $TriggerMetadata)

# Write out the blob name and size to the information log.
Write-Host "PowerShell Blob trigger function Processed blob! Name: $($TriggerMetadata.Name) Size: $($InputBlob.Length) bytes"
Write-Host "Metadata: $($TriggerMetadata)"
$BaseDirectory = "D:\home\site\wwwroot\BlobTrigger1"

# Download epub file from blob storage
try{
    Enable-AzureRmAlias
    # Create context using connectionString
    $ConnectionString = $env:renoshStorage
    $Ctx = New-AzureStorageContext -ConnectionString $ConnectionString

    # Create temp directory 
    New-Item -Path $BaseDirectory -Name "temp" -ItemType "directory"

    # Download epub file from blob storage and save file to /temp directory
    $localTargetDirectory = "$($BaseDirectory)\temp"
    $ContainerName  = "epub"
    $epubFileName = "$($TriggerMetadata.Name).epub"
    Write-Host "EpubFileName: $($epubFileName)"
    Get-AzureStorageBlobContent -Blob $epubFileName -Container $ContainerName -Destination $localTargetDirectory -Force -Context $Ctx
} catch {
    Write-Host "Something went wrong to store Epub file."
    Write-Host $_.ScriptStackTrace
}

# Execute exiftool 
try {
    # Temporaily save epub file to current path
    Set-Location $BaseDirectory
    $fileName = "temp\$($TriggerMetadata.Name).epub"
    Write-Host "FileName: $($fileName)"
    # execute exiftool and save result to output variable
    $output = .\exiftool.exe $fileName -json
    Write-Host "Successfully execute exiftool" 
} catch {
    Write-Host "Something went wrong to execute exiftool"
    Write-Host $_.ScriptStackTrace
}

# save result to cosmos DB
try {
    Write-Host "Output result: $($output)"
    $output = $output | ConvertFrom-Json -AsHashtable
    Push-OutputBinding -Name outputDocument -Value $output
    Write-Host "object has been added to the cosmosDB"
} catch {
    Write-Host "Something went wrong to store data to cosmosDB"
    Write-Host $_.ScriptStackTrace
}

# Clean up resources
try {
    Remove-Item -path "$($BaseDirectory)\temp" -recurse
}catch {
    Write-Host "Something went wrong to delete temp directory"
    Write-Host $_.ScriptStackTrace
}
