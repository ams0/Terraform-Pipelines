[CmdletBinding()]
param (
    [string]$SourcePath = "..\..",
    [string]$OutputPath = "C:\temp\lucidity\output"
)

$verbose = $false
if ($PSBoundParameters.ContainsKey('Verbose')) { # Command line specifies -Verbose[:$false]
    $verbose = $PsBoundParameters.Get_Item('Verbose').IsPresent
}

$tarFlags="-czf"
if ($verbose){
  $tarFlags="-czvf"
}

# Create Output folder
Write-Host "Creating $outputPath directory."
New-Item -ItemType Directory -Force -Path $outputPath | out-null

# Delete old tar files
Write-Verbose "Cleaning out $outputPath directory."
Get-ChildItem -Path $outputPath -Include *.tar.gz -File -Recurse | foreach { $_.Delete()}

Write-Host "Generating $outputPath\terraform-pipelines.tar.gz"
tar $tarFlags $outputPath\terraform-pipelines.tar.gz -C $sourcePath Terraform-Pipelines 

Write-Host "Generating $outputPath\terraform-code.tar.gz"
tar $tarFlags $outputPath\terraform-code.tar.gz -C $sourcePath Terraform-Code