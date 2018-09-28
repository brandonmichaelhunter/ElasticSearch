<#
.SYNOPSIS
 Run-ForceMerge.ps1 is a script that will run the ForceMerge command against the cluster that reduce the number of segments for each index per date. 

.DESCRIPTION
 Use this script as a solution to reduce the segment count in your cluster.
 For more information about the ForceMerge command, check out this link - https://www.elastic.co/guide/en/elasticsearch/reference/5.4/indices-forcemerge.html

.PARAMETER ESUrl
 Url refers to url for you ElasticSearch cluster.
.PARAMETER Username
 Refers to a username for an account that has the ability to modify cluster and indices settings.
.PARAMETER Password
 Refers to a password for an account that has the ability to modify cluster and indices settings.
.PARAMETER NumberOfReportingDays
 Represents the number of days in the past that the script should run against.
.PARAMETER NumberOfSecondsToSleep
 Represents the number of seconds to sleep before checking again if the group indicies has been completed.
.PARAMETER EnableDebug
 Outputs the program transactions to the conosle screen.
.PARAMETER TestRun
 Simulates the action of the script.

.EXAMPLE
 - This will run the command without debugging and simulation enabled.
 .\Run-ForceMerge.ps1 -Url 'https://clusterurl:9200' -Username 'elastic' -Password 'changeme' -NumberOfReportingDays 45 -NumberOfSecondsToSleep 120 -EnableDebug False -TestRun False

.EXAMPLE
 - This will run the command with debugging enabled
 .\Run-ForceMerge.ps1 -Url 'https://clusterurl:9200' -Username 'elastic' -Password 'changeme' -NumberOfReportingDays 45 -NumberOfSecondsToSleep 120 -EnableDebug True -TestRun False

.EXAMPLE
 - This will run the command in simulation mode.
 .\Run-ForceMerge.ps1 -Url 'https://clusterurl:9200' -Username 'elastic' -Password 'changeme' -NumberOfReportingDays 45 -NumberOfSecondsToSleep 120 -EnableDebug False -TestRun True
#>

[CmdletBinding()]Param([Parameter(Mandatory=$True, Position=1)] [string] $ESUrl,
                       [Parameter(Mandatory=$True, Position=2)] [string] $Username, 
                       [Parameter(Mandatory=$True, Position=3)] [string] $Password, 
                       [Parameter(Mandatory=$True, Position=4)] [int] $NumberOfReportingDays, 
                       [Parameter(Mandatory=$True, Position=5)] [int] $NumberOfSecondsToSleep,
                       [Parameter(Mandatory=$False, Position=6)][bool] $EnableDebug,
                       [Parameter(Mandatory=$False, Position=7)] [bool] $TestRun)


$IndexMasterList = New-Object System.Collections.Generic.List[string]
$ExpectedNumberOfSegements = 0
$DateRangesList = New-Object System.Collections.Generic.List[string]

function WriteLog([string]$Message, [bool]$IsDebug){
    try 
    { 
        $RecordedDateTime = Get-Date -Format ‘MM-dd-yy - HH:mm:ss’ 
        $FilePath = "$(Convert-Path .)\ScriptLog.log"
        Add-Content -Value "$RecordedDateTime - $Message" -Path $FilePath 
        if($EnableDebug -eq $true){
            Write-Host $Message
            Write-Host ""     
        }
    } 
    catch 
    { 
        Write-Error $_.Exception.Message 
    }   
}
function GenerateDatesRangeList($NumberOfReportingDays){
    # Get the date before today in the format yyyy.MM.dd
    $CurrentDate = (Get-Date -format yyyy.MM.dd) # Capture the current date

    $DatesList = New-Object System.Collections.Generic.List[string]
    for($a = $NumberOfReportingDays; $a -le -1; $a++){
        $PreformatDate = (Get-Date).AddDays($a)
        $FormattedDate = Get-Date $PreformatDate -Format yyyy.MM.dd
        $DatesList.Add($FormattedDate)
    }
    return $DatesList
}
function GetSegmentsResponse([string] $Date){
    # Make the rest call to get all segements for a specific date.
    $uri      = "$($ESUrl)/_cat/segments/*$($Date)?format=json&v"
    $creds    = $null
    $pwd      = ConvertTo-SecureString $Password -AsPlainText -Force
    $creds    = New-Object Management.Automation.PSCredential ($Username, $pwd)
    $response = Invoke-RestMethod -Method GET -Uri $uri  -cred $creds 
    return $response
}
function GetUniqueIndexNames($SegmentResponseData){
    $IndexUniqueNamesList = New-Object System.Collections.Generic.List[string]
    $IndexUniqueNamesList = ($SegmentResponseData | Select index -Unique)
    return $IndexUniqueNamesList
}

function GetIndexNames($ResponseData){
    $IndexNamesList = New-Object System.Collections.Generic.List[string]
    $NewIndexName = ""
    $OldIndexName = "" 
    $IndexNames = ""
    for($b = 0; $b -le $ResponseData.Count-1; $b++)
    {
       $IndexName = $ResponseData[$b].Split(" ")[0].ToString()
       $IndexNamesList.Add($IndexName)
    }
    return $IndexNamesList
}
# Loop through the $DateRangesList 
function ExecuteForceMerge($Date){
    WriteLog("Started - Executing ForceMerge command on indexes created on $($Date)") 
    try
    {
        # ExecuteForceMerge command
        $uri      = "$($ESUrl)/*$($Date)/_forcemerge?max_num_segments=1"
        $creds    = $null
        if($TestRun -eq $false){
            $pwd      = ConvertTo-SecureString $Password -AsPlainText -Force
            $creds    = New-Object Management.Automation.PSCredential ($Username, $pwd)
            $response = Invoke-RestMethod -Method POST -Uri $uri  -cred $creds -ErrorAction Stop  | Out-Null
        }
    }
    catch
    {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        $Message = "Error: $($FailedItem) - Message: $($ErrorMessage)"
        WriteLog($Message, $false)
    }
    
   WriteLog("Completed - Executing ForceMerge command on indexes created on ($($Date)")

}

# Retrieves the number of nodes that are in a cluster.
function GetClusterNodeCount(){
    # Query the indicies api to get the number of primary shards for an index.
    $queryNodeTable = "$($ESUrl)/_nodes/stats/os?pretty&format=json"
    $creds    = $null
    $pwd      = ConvertTo-SecureString $Password -AsPlainText -Force
    $creds    = New-Object Management.Automation.PSCredential ($Username, $pwd)
    $nodeTableResults = Invoke-RestMethod -Method GET -Uri $queryNodeTable -cred $creds -ErrorAction Stop  
    $nodeMetadata   = ($nodeTableResults | Select _nodes)
    $nodeCount = [int]$nodeMetadata._nodes.total
    return $nodeCount
}

function GetIndexPrimaryShardCount($IdxName){
    # Query the indicies api to get the number of primary shards for an index.
    $queryIndexDetails         = "$($ESUrl)/_cat/indices/$($IdxName)?v&h=pri,rep&format=json"
    $creds                     = $null
    $pwd                       = ConvertTo-SecureString $Password -AsPlainText -Force
    $creds                     = New-Object Management.Automation.PSCredential ($Username, $pwd)
    $queryIndexDetailsResponse = Invoke-RestMethod -Method GET -Uri $queryIndexDetails -cred $creds -ErrorAction Stop  
    $indexShardMetadata        = ($queryIndexDetailsResponse | Select pri, rep)
    $primaryShardsCount        = [int]$indexShardMetadata.pri
    $replicaShardsCount        = [int]$indexShardMetadata.rep
    $clusterNodeCount          = GetClusterNodeCount
    $shardCount                = 0
    if($replicaShardsCount -eq 0)
    {
        $shardCount = $primaryShardsCount
    }
    elseif($clusterNodeCount -eq 1){
        # Only half of the shards will have segments.
        $shardCount = [math]::Round(((($primaryShardsCount * 2) * $replicaShardsCount) /2))
    }
    else{
        $shardCount = (($primaryShardsCount * 2) * $replicaShardsCount)
    }

    return $shardCount
}
function GetIndexActualSegmentCount($IndexList, $IdxName){
    return ($IndexList | Where-Object { $_.index -eq $IdxName } | Measure-Object).Count
}
function ConfirmForceMergeIsComplete($Date){
        $StartDate = (Get-Date).ToShortDateString()
        $StartTime = (Get-Date).ToShortTimeString()
        $StartDT = "$($StartDate) - $($StartTime)"
        WriteLog("*** Start Date and Time: $($StartDT)")
        if($TestRun -eq $false)
        {
            # Get Segements data
            WriteLog("Started - Get Segements Data")
            $SegmentResponse = GetSegmentsResponse($Date)
            WriteLog("Completed - Get Segements Data")

            # Initialize lists
            $IndexMasterList = New-Object System.Collections.Generic.List[string]
            $IndexNamesList  = New-Object System.Collections.Generic.List[string]

        

            if($SegmentResponse -ne ""){
                #$SegmentsData = $SegmentResponse.Split([Environment]::NewLine)

                # Generate a list of unique index names from the response data.
                $IndexMasterList = GetUniqueIndexNames($SegmentResponse)

                # Get a list of all the current indexes from the response data
                $IndexNamesList = $SegmentResponse | Select index #GetIndexNames($SegmentsData)
                
                WriteLog("Processing Indexes")
                # Process the unique index and confirm that only 6 occurences of an index exists.
                for($c = 0; $c -le $IndexMasterList.Count - 1; $c++){
                    $IndexName = $IndexMasterList[$c].index

                    # Get the expected segment count for the current index.
                    $IndexExpectedSegmentCount = GetIndexPrimaryShardCount($IndexName)
                    
                    # Get the actual segment count for the current index.
                    $IndexActualSegmentCount = ($IndexNamesList | Where-Object { $_.index -eq $IndexName } | Measure-Object).Count 
                    
                    WriteLog("Processing $($IndexName)")

                    # If the count is not equal to 6, then continue onto the next index.
                    $IndexCompleted = $false
                    while($IndexCompleted -eq $false){
                        WriteLog("Expected number of segements for $($IndexName) is - $($IndexExpectedSegmentCount)")    
                        WriteLog("Actual number of segements for $($IndexName) is - $($IndexActualSegmentCount)")    

                        if($IndexActualSegmentCount -gt $IndexExpectedSegmentCount){
                            Write-Host ""
                            # Sleep for 15 minutes
                            Start-Sleep -Seconds $NumberOfSecondsToSleep
                            $SegmentsData = $null
                            $IndexNamesList  = New-Object System.Collections.Generic.List[string]
                            $SegmentResponse = GetSegmentsResponse($Date)
                            $IndexNamesList = $SegmentResponse | Select index
                            $IndexExpectedSegmentCount = GetIndexPrimaryShardCount($IndexName)
                            $IndexActualSegmentCount = ($IndexNamesList | Where-Object { $_.index -eq $IndexName } | Measure-Object).Count 
                        }
                        else{

                            $IndexCompleted = $true
                            WriteLog("**** Force Merge complete on index: $($IndexName).")
                            
                        
                        }
                    }
                  }
              }
          }
          $EndDate = (Get-Date).ToShortDateString()
          $EndTime = (Get-Date).ToShortTimeString()
          $EndDT = "$($EndDate) - $($EndTime)"
          WriteLog(Write-Host "**** End Date and Time: $($EndDT)")
}
function ConfirmedDateIndexesHasBeenProcessed($CurrentDate){
     $isDateIndexInstanceCompleted = $true
     #query the Segements API for indexes created on the $CurrentDate parameter value.
     $querySegementsAPI = "$($ESUrl)/_cat/segments/*$($CurrentDate)?v&h=index&format=json"
     $pwd      = ConvertTo-SecureString $Password -AsPlainText -Force
     $creds    = New-Object Management.Automation.PSCredential ($Username, $pwd)
     $querySegementsAPIResponse = Invoke-RestMethod -Method GET -Uri $querySegementsAPI  -cred $creds -ErrorAction Stop
     $segmentsResponseList = ($querySegementsAPIResponse | SELECT index)
     
     # Loop through the response
     for($a = 0; $a -le $segmentsResponseList.Length-1; $a++){
         
         # Get index name
         $indexName = $segmentsResponseList[$a].index 

         # Get the expected number of segments listed for the current index.
         $expectedNumberOfIndexCount = GetIndexPrimaryShardCount($indexName)

         # Get the actual number of segments listed for the current index.
         $actualNumberOfIndexCount = ($querySegementsAPIResponse | Where-Object { $_.index -eq $IndexName } | Measure-Object).Count 

         # Check to see if the actual number and the expected does not match. If the two variables does not match, 
         # then we need to run the ForceMerge command on the indexes of the current process date ($CurrentDate)
         if ($actualNumberOfIndexCount -ne $expectedNumberOfIndexCount){
            $isDateIndexInstanceCompleted = $false
            break
         }
     }
     return $isDateIndexInstanceCompleted
}
function GetSegmentsStats(){
    # Query the indicies api to get the number of primary shards for an index.
    $nodeSegmentQuery = "$($ESUrl)/_cluster/stats?format=json"
    $creds    = $null
    $pwd      = ConvertTo-SecureString $Password -AsPlainText -Force
    $creds    = New-Object Management.Automation.PSCredential ($Username, $pwd)
    $nodeQueryResults = Invoke-RestMethod -Method GET -Uri $nodeSegmentQuery -cred $creds -ErrorAction Stop
    # Write the nodes stats to the logs
    WriteLog("Segment Stats")
    WriteLog("Count: $($nodeQueryResults.indices.segments.count)")
    WriteLog("Memory in bytes: $($nodeQueryResults.indices.segments.memory_in_bytes)")
}
function Main(){
    $StopWatch = [system.diagnostics.stopwatch]::startNew()
    GetSegmentsStats

    $DatesRangeList = GenerateDatesRangeList($NumberOfReportingDays)
    for($a = 0; $a -le  $DatesRangeList.Count - 1;$a++){
        $ProcessDate = $DatesRangeList[$a]
        WriteLog("***** Processing Date: $($ProcessDate) *****\n")
        
        $results = ConfirmedDateIndexesHasBeenProcessed($ProcessDate)
        if ($results -eq $true){
            WriteLog("No need to execute the force merge command on date $($ProcessDate). Moving onto the next date")
        }
        else{
            WriteLog("Executing a form merge comamnd on date $($ProcessDate)")
            
            #Execute force Merge
            if($ProcessDate -ne "2018.01.25")
            {
                ExecuteForceMerge($ProcessDate)
            }

            #Configure that the force merge process was complete on all indexes based on the provided date ($Date)
            ConfirmForceMergeIsComplete($ProcessDate)
        }
    }
    
    GetSegmentsStats
    $StopWatch.Stop()
    Write-Host $StopWatch.Elapsed.TotalSeconds -ForegroundColor Green
}
Main 

 
