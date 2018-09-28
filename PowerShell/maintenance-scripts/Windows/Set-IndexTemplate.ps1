<#
.SYNOPSIS
 Set-IndexTemplate.ps1 - Eitehr adds or update an index template. 
.DESCRIPTION
 Use this script when you want to add or update an index template within a cluster. 

.PARAMETER Url
 Url refers to url for you ElasticSearch cluster.
.PARAMETER Username
 Refers to a username for an account that has the ability to modify cluster and indices settings.
.PARAMETER Password
 Refers to a password for an account that has the ability to modify cluster and indices settings.
.PARAMETER FilePathToJSONFile
 Represents the file path to a json file that has the index template.
.PARAMETER TestRun
 Enables the console to run in a simulation mode.

.EXAMPLE
# Sets the index template with a username and password
.\Set-IndexTemplate -Url 'https://clusterurl:9200' -Username 'elastic' -Password 'changeme' -FilePathToJSONFile '.\IndexTemplate.json' -TestRun $False

.EXAMPLE
# Sets the index template and request the username and password
.\Set-IndexTemplate -Url 'https://clusterurl:9200' -Username 'elastic' -Password 'changeme' -FilePathToJSONFile '.\IndexTemplate.json' -TestRun $False

.EXAMPLE
# Run the script in simulation mode.
.\Set-IndexTemplate -Url 'https://clusterurl:9200' -Username 'elastic' -Password 'changeme' -FilePathToJSONFile '.\IndexTemplate.json' -TestRun $False

#>

[CmdletBinding(PositionalBinding=$false)]Param(
                            [Parameter(Mandatory=$True, Position=0)][string] $Url,
                            [Parameter(Mandatory=$True,Position=1)][string] $TemplateName,
                            [Parameter(Mandatory=$True, Position=2)][string] $FilePathToJSONFile,
                            [Parameter(Mandatory=$True, Position=3)][bool] $TestRun)



# Verify that the FilePathToJSONFile exists
if (-NOT (Test-Path $FilePathToJSONFile)){
    Write-Host "JSON file $($FilePathToJSONFile) does not exists. Please provide a valid file and file to your index template file." -ForegroundColor Red
    Exit
}
# Verify that a template name was provided.
if($TemplateName -eq "" -or $TemplateName -eq $null){
    Write-Host "Please provide a template name." -ForegroundColor Red
    Exit
}

# Display script contents
$indexTemplate = Get-Content -Raw -Path $FilePathToJSONFile 
Write-Host "This is the index templat that we will add to the cluster." -ForegroundColor Yellow
Write-Host $jsonObj -ForegroundColor Green

# If the user has not provided user credentials, then ask for it.
$UserCreds = $Host.ui.PromptForCredential("Requesting ElasticSearch Credentails", "Please enter your ElasticSearch's user name and password.", "", "ElasticSearch")

# Check to see if the index template already exists.
$uri = "$($Url)/_template/$($TemplateName)"
Write-Host "Checking to see if $($TemplateName) exists." -ForegroundColor Yellow
Write-Host "Url: $($uri)" -ForegroundColor Green
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/json")
$response = Invoke-RestMethod -Method PUT  -Uri $uri -Body $indexTemplate -cred $UserCreds -Headers $headers

