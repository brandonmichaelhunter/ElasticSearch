
cls # clear the console screen.
$global:ESUrl                 = $null  # elasticsearch host url
$global:UserCredentials       = $null  # execution user account credentails.
$global:ENVProfile            = $null  # environment profile.
$global:ESServiceName         = $null  # elasticsearch service name
$global:KibanaSerivceName     = $null  # kbiana service name
$global:IsKibanaMachine       = $false # confirm if this machine has kibana installed.
$global:ClusterDiagnosticPath = $null  # cluster diagnostic file path
$global:DiagnosticCommand     = $null  # cluster diagnostic command line
$global:RestoreClusterState   = $null  # the cluster state that indicates that the cluster has been restored.
$global:ClusterInitState      = $null  # the start cluster state.
function LogWork([string] $Msg, [string] $Color){
    Write-Host $Msg 
}
function CopyFile(){
    $SrcLoc = Read-Host "Type in the folder location and the file name of where your jks file is located"
    $DestLoc = Read-Host "Great, where should we move the file too"
    Copy-Item $SrcLoc $DestLoc -ErrorAction Stop
}
function DisableClusterIndexing(){
    GetClusterCoreFeatures
    $DisableClusterUrl = $global:ESUrl +"/*/_settings"
    Write-Host ""
    Write-Host "Started: Disable Cluster Indexing" -ForegroundColor Yellow
    Invoke-RestMethod -Method PUT -Uri $DisableClusterUrl -ContentType 'application/json'-Body '{"index.blocks.read_only": "true"}' -cred $global:UserCredentials -ErrorAction Stop | Out-Null
    Write-Host "Completed: Disable Cluster Indexing" -ForegroundColor Green
}
function EnableClusterIndexing(){
    GetClusterCoreFeatures
    $settingsUrl = $global:ESUrl +"/*/_settings"
    Write-Host ""
    Write-Host "Started: Enable Cluster Indexing" -ForegroundColor Yellow
    Invoke-RestMethod -Method PUT -Uri $settingsUrl -ContentType 'application/json'-Body '{"index.blocks.read_only": "false"}' -cred $global:UserCredentials -ErrorAction Stop | Out-Null
    Write-Host "Completed: Enable Cluster Indexing" -ForegroundColor Green
}
function ExecuteQuerySynchFlushed(){
   GetClusterCoreFeatures
   $QuerySyncUrl = $global:ESUrl + "/_flush/synced"
   Write-Host ""
   Write-Host "Started: Perform Synced Flush Request" -ForegroundColor Yellow
   Invoke-RestMethod -Method POST -Uri $QuerySyncUrl -ContentType 'application/json' -cred $global:UserCredentials -ErrorAction Stop | Out-Null
   Write-Host "Completed: Perform Synced Flush Request" -ForegroundColor Green
}
function DisableShardAllocation(){
    GetClusterCoreFeatures
    $DisableShardAllocationUrl = $global:ESUrl +"/_cluster/settings"
    Write-Host ""
    Write-Host "Started: Disable Shard Allocation" -ForegroundColor Yellow
    Invoke-RestMethod -Method PUT -Uri $DisableShardAllocationUrl -ContentType 'application/json'-Body '{"persistent": {"cluster.routing.allocation.enable": "none"}}' -cred $global:UserCredentials -ErrorAction Stop | Out-Null
    #Invoke-RestMethod -Method PUT -Uri $DisableShardAllocationUrl -ContentType 'application/json'-Body '{"transient": {"cluster.routing.allocation.enable": "none"}}' -cred $cred -ErrorAction Stop | Out-Null
    Write-Host "Completed: Disable Shard Allocation" -ForegroundColor Green
}
function EnableShardAllocation(){
    GetClusterCoreFeatures
    $clusterSettingsUrl = $global:ESUrl +"/_cluster/settings"
    Write-Host ""
    Write-Host "Started: Enable Shard Allocation" -ForegroundColor Yellow
    Invoke-RestMethod -Method PUT -Uri $clusterSettingsUrl -ContentType 'application/json'-Body '{"persistent": {"cluster.routing.allocation.enable": "all"}}' -cred $global:UserCredentials -ErrorAction Stop | Out-Null
    #Invoke-RestMethod -Method PUT -Uri $DisableShardAllocationUrl -ContentType 'application/json'-Body '{"transient": {"cluster.routing.allocation.enable": "none"}}' -cred $cred -ErrorAction Stop | Out-Null
    Write-Host "Completed: Enable Shard Allocation" -ForegroundColor Green
    ######## TODO ########
    # Improving recovery time
    Write-Host ""
    Write-Host "Enabling cluster recovery boosters" -ForegroundColor Yellow
    Invoke-RestMethod -Method PUT -Uri $clusterSettingsUrl -ContentType 'application/json' -Body '{"persistent": {"xpack.monitoring.collection.interval": -1,"cluster.routing.allocation.node_concurrent_recoveries": "15","cluster.routing.allocation.node_initial_primaries_recoveries": "15", "indices.recovery.max_bytes_per_sec": "300mb"}}' -cred $global:UserCredentials -ErrorAction Stop | Out-Null
    Write-Host "Enabled cluster recovery boosters" -ForegroundColor Green
    Write-Host ""
    # Monitor the cluster recover
    $currentExecutionDate = (Get-Date).ToShortDateString() 
    $CurrentClusterStatus = "red"
    Write-Host ""
    Write-Host "Cluster stauts update will occur every 30 seconds." -ForegroundColor Yellow
    Write-Host ""
    while($CurrentClusterStatus -ne $global:RestoreClusterState)
    {
        # Get the current execution date and time
		$currentExecutionDateTime = (Get-Date).ToShortTimeString()
        $Url =  $global:ESUrl +"/_cluster/health?pretty"
        # Get the cluster status health
		$results = Invoke-RestMethod -Method GET -Uri $Url -cred $global:UserCredentials
        $CurrentClusterStatus = $results.status
        $ActiveShardsPercentAsNumber = $results.active_shards_percent_as_number
        $NumberOfActiveNodes = $results.number_of_nodes
		if($CurrentClusterStatus -ne $global:RestoreClusterState ){
			Write-Host "ElasticSearch Status: $($CurrentClusterStatus) - Percentage to completion: $($ActiveShardsPercentAsNumber) - Active Nodes: $($NumberOfActiveNodes) - Current Time: $($currentExecutionDateTime)"  -Foreground $CurrentClusterStatus
			Start-Sleep -s 30
		}
		
		else{
			Write-Host "ElasticSearch Status: $($CurrentClusterStatus) - Has Been Restored - Restored Time: $($currentExecutionDateTime)"  -Foreground Green
			break
		}
	}
    Write-Host ""
	Write-Host "Disabling cluster recovery booters" -ForegroundColor Yellow
	Invoke-RestMethod -Method PUT -Uri $clusterSettingsUrl -ContentType 'application/json' -Body '{"persistent": {"xpack.monitoring.collection.interval": null,"cluster.routing.allocation.node_concurrent_recoveries": null,"cluster.routing.allocation.node_initial_primaries_recoveries": null, "indices.recovery.max_bytes_per_sec": null}}' -cred $global:UserCredentials -ErrorAction Stop | Out-Null
    Write-Host "Disabled cluster recovery booters" -ForegroundColor Green
    Write-Host ""

	
}
function GetClusterCoreFeatures(){
   if($global:UserCredentials -eq $null)
   {
       #Save the credentials to global variables scope so that we do not have to asks the user to enter them again within their current session.

       $username               = $global:ENVProfile.CREDS.username
       $password               = ConvertTo-SecureString  $global:ENVProfile.CREDS.password -AsPlainText -Force
       $global:UserCredentials = New-Object Management.Automation.PSCredential ($username, $password)
    }
}
function StopElasticSearchService(){
        $windowServicesList = $null
 	    Write-Host "Searching for ElasticSearch service....." -ForegroundColor Yellow
        $windowServicesList = Get-Service | Where-Object {$_.Name -like "*$($global:ESServiceName)*"} | Select-Object @{ Name = "ServiceID" ; Expression= {$global:counter; $global:counter++} }, Name, DisplayName
		Write-host "Stoping $($global:ESServiceName) service." -ForegroundColor Yellow
		Stop-Service -Name $global:ESServiceName
		Write-Host "$($global:ESServiceName) service has been stopped." -ForegroundColor Green
   
}
function StartElasticSearchService(){
        $windowServicesList = $null
	    Write-host "Starting $($global:ESServiceName) service." -ForegroundColor Yellow
		Start-Service -Name $global:ESServiceName
		Write-Host "$($global:ESServiceName) service is now started." -ForegroundColor Green
}
function StopKibanaService(){
        $windowServicesList = $null
 	    Write-Host "Searching for Kibana service....." -ForegroundColor Yellow
        $windowServicesList = Get-Service | Where-Object {$_.Name -like "*$($global:KibanaSerivceName)*"} | Select-Object @{ Name = "ServiceID" ; Expression= {$global:counter; $global:counter++} }, Name, DisplayName
		Write-host "Stoping $($global:KibanaSerivceName) service." -ForegroundColor Yellow
		Stop-Service -Name $global:KibanaSerivceName
		Write-Host "$($global:KibanaSerivceName) service has been stopped." -ForegroundColor Green
   
}
function StartKibanaService(){
        $windowServicesList = $null
	    Write-host "Starting $($global:KibanaSerivceName) service." -ForegroundColor Yellow
		Start-Service -Name $global:KibanaSerivceName
		Write-Host "$($global:KibanaSerivceName) service is now started." -ForegroundColor Green
}
function CreateSnapshot(){
    #Create ElasticSearch url and user credentails
    GetClusterCoreFeatures
    
    # Get repository name
    $repositoryName = GetRepositoryName

    #Create snapshot.
    Write-Host "Started: Creating snapshot" -ForegroundColor Yellow
    $snapShotObj = @{}
    $snapshotName = "$(get-date -f yyyy_MM_dd_HH_MM_ss)_snapshot"
    $snapShotUrl = $global:ESUrl +"/_snapshot/$($repositoryName)/$($snapshotName)?wait_for_completion=true"
    Invoke-RestMethod -Method PUT -Uri $snapShotUrl -ContentType 'application/json' -cred $global:UserCredentials -ErrorAction Stop | Out-Null
    Write-Host "Completed: Creating snapshot" -ForegroundColor Green
    Write-Host ""
}
function CreateRepository([string] $repoName){
        Write-Host "*****************************" -ForegroundColor Yellow
        Write-Host "Started: Creating Repository" -ForegroundColor Yellow
        $repositoryPath = $global:ESUrl +"/_snapshot/$($repoName)"
        $snapshotObj = '{"type": "fs", "settings":{"location":"$($repoName)", "compress": true}}'
        [hashstable] $snapshotObj = @{}
        $snapshotObj.type="fs"
        $snapshotObj.settings = @{}
        $snapshotObj.settings.location = $repoName
        $snapshotObj.settings.compress = $true
        $snapshotParameter = $snapshotObj | ConvertTo-Json
        Invoke-RestMethod -Method PUT -Uri $repositoryPath -ContentType 'application/json'-Body $snapshotParameter -cred $global:UserCredentials -ErrorAction Stop | Out-Null
        Write-Host "Completed: Creating Repository" -ForegroundColor Green
        Write-Host "******************************" -ForegroundColor Yellow
}
function GetRepositoryName(){
    # GetClusterCoreFeatures
    Write-Host ""
    $repoName  = Read-Host "Please provide a repository name. If the name doesn't exists, then we will create one for you"
    $repoExist = DoesRepositoryExists($repoName)
    if($repoExist -eq $false){
        $invalidRequest = $true
        do{
            $createRepo = Read-Host "$($repoName) does not exists. Do you want to create a new repository (Y\N)"
            if($createRepo.ToUpper() -eq "Y"){
                CreateRepository($repoName)
                $invalidRequest = $false   
            }
            elseif($createRepo.ToUpper() -eq "N"){
                $invalidRequest = $false
                $repoName = $null
            }
            else{
                Write-Host "You have entered an invalid request." -ForegroundColor Red
            }
        }while($invalidRequest -eq $true)
    }

    
    return $repoName
}
function GetSnapshot([string] $repoName){
    #Retrieve a list of snapshots to select from
    $choiceSelected = $false
    do{
        $repoUrl = $global:ESUrl +"/_snapshot/$($repoName)"
        $snapshotResponse = Invoke-RestMethod -Uri $repoUrl | ConvertTo-Json
        $snampshotsList = $snapshotResponse | ConvertFrom-Json
    }while($choiceSelected -eq $false)
}
function GetRepositoryList(){
    #Build url
    $repoUrl = $global:ESUrl +"/_snapshot" 
    $response = Invoke-RestMethod $repoUrl | ConvertTo-Json
    $list = $response | ConvertFrom-Json #rename variable to something meaningful :)
    $counter = 0
    $retList = @()
    Write-Host $list
    foreach($item in $list.psobject.Properties)
    {
       $repoObj = @{"ID"=$counter++; "RepositoryName"=$item.Name}
       $repoObject = New-Object PSObject -Property $repoObj
       $retList += $repoObject  
    }
    return $retList
}
function DeleteSnapshot(){
 #User enter in snapshot name to begin search
 #User selects a snapshot name
 #Script delete snapshot.
}
function isNumeric($value){
    
    #$x2 = 0
    #$isNum = [System.Int32]::TryParse($value, [ref]$x2)
    #$isNum
    try{
     0 + $value | Out-Null
     return $true
    } catch{return $false}
    
}
function GetSnapshots([string] $repositoryName){
    $repoUrl = $global:ESUrl +"/_snapshot/$($repositoryName)/*" 
    $response = Invoke-RestMethod $repoUrl | ConvertTo-Json
    $list = $response | ConvertFrom-Json #rename variable to something meaningful :)
    

    $counter = 0
    $snapshotList = @()
    
    foreach($item in $list.snapshots)
    {
       $snapshotObj = @{"ID"=$counter++; "SnapshotName"=$item.snapshot}
       $snapshotObject = New-Object PSObject -Property $snapshotObj
       $snapshotList += $snapshotObject  
    }
    return $snapshotList
}
function RestoreSnapshot() {
 #User enter in snapshot name to search from.
 GetClusterCoreFeatures
 #Select from a list of respositories
 $optionSelected = $false
 $repoList = $null
 $item = $null
 do
 {
    $repoList     = GetRepositoryList
    $repoList | Format-Table -AutoSize
    $repoSelected = $false   
    $selRepo      = Read-Host "Type in the ID value of the repository name that you want to select"
    $isNum        = isNumeric($selRepo)
    
    if($isNum -eq $false)
    {
        Write-Host "Invalid input, please try again." -ForegroundColor Red
    }
    else
    {
        $item = $repoList | Where {$_.ID -eq $selRepo}
        if($item -eq $null){
            Write-Host "Invalid input, please try again." -ForegroundColor Red
        }
        else{
            $optionSelected = $true;
        }
    }

 }while($optionSelected -eq $false)
 $repositoryName = $item.RepositoryName
 Write-Host $repositoryName
 $optionSelected = $false
 do{
      #Retrieve snapshot
      #TODO - code is not entering into this loop for some reason.
      $snapshotList = GetSnapshots($repositoryName)
      $snapshotList | Format-Table -AutoSize
      $optionSelected = $true
      $selSnapshotID = Read-Host "Please select the ID value of the snapshot that you want to restore"
      $selSnapshot   = $null
      $isNum        = isNumeric($selSnapshot)

      if($isNum -eq $false){
        Write-Host "Invalid input, please try again." -ForegroundColor Red
      }
      else{
        $item = $snapshotList | Where {$_.ID -eq $selSnapshotID}
        if($item -eq $null){
            Write-Host "Invalid input, please try again." -ForegroundColor Red
        }
        else{
            $selSnapshot = $item.SnapshotName
            $optionSelected = $true;
        }
      }
    
 }while($optionSelected -eq $false)

 Write-Host "Started: Restore snapshot" -ForegroundColor Yellow
 #Before restorting, we must close all indexes.
 # Restore snapshot
 $restoreUrl = $global:ESUrl +"/_snapshot/$($repositoryName)/$($selSnapshot)/_restore" 
 $response = Invoke-RestMethod -Method Post -Uri $restoreUrl
 Write-Host "Completed: Restore snapshot" -ForegroundColor Green
 #do
 #{
    #Display a list of repository to select from
 #   Where-Object {$_.Name -like "*$($srchSvcName)*"} | Select-Object @{ Name = "ServiceID" ; Expression= {$global:counter; $global:counter++} }, Name, DisplayName

 #}while($repoSelected -eq $false)
 #User selects snapshot name.
 #Script restores snapshot back to ElasticSearch
}
function DoesRepositoryExists([string] $repoName){
    $snapShotUrl = $repositoryPath = $global:ESUrl +"/_snapshot?human&pretty"
    $response = Invoke-RestMethod  $snapShotUrl | ConvertTo-Json
    return $response.Contains($repoName)
}
# RunClusterDiagnotics() - this will run ElasticSearch diagnostic against the cluster.

function RunAsAdmin(){
    # Get the ID and security principal of the current user account
    $myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
    $myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
 
    # Get the security principal for the Administrator role
    $adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
 
    # Check to see if we are currently running "as Administrator"
    if ($myWindowsPrincipal.IsInRole($adminRole)){
       # We are running "as Administrator" - so change the title and background color to indicate this
       $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)"
       $Host.UI.RawUI.BackgroundColor = "DarkBlue"
       clear-host
    }
    else
    {
       # We are not running "as Administrator" - so relaunch as administrator
   
       # Create a new process object that starts PowerShell
       $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";
   
       # Specify the current script path and name as a parameter
       $newProcess.Arguments = $myInvocation.MyCommand.Definition;
   
       # Indicate that the process should be elevated
       $newProcess.Verb = "runas";
   
       # Start the new process
       [System.Diagnostics.Process]::Start($newProcess);
   
       # Exit from the current, unelevated, process
       exit
    }
    # Run your code that needs to be elevated here
    Write-Host -NoNewLine "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function WebsiteAvalaible([string] $WebsiteURL){
    [Boolean] $retResults = $False
    try
    {
        $result1 = Measure-Command { $request = Invoke-WebRequest -Uri $WebsiteURL } 
        $retResults = $True
    }
    catch
    {
        Write-Host $_.Exception 

    }
    $returnResponse = $request
    return $retResults
}
function RunClusterDiagnosticReport(){
    # Check if folder exists.
    Write-Host "Check to see if $($global:DiagnosticCommand) exists on your current machine" -ForegroundColor Yellow
    $PathExists = Test-Path $global:ClusterDiagnosticPath
    if($PathExists -eq $True){
        Write-Host "$($global:DiagnosticCommand) folder exists" -ForegroundColor Green

        
    }
}
function Get-ScriptDirectory {
  Split-Path -Parent $PSCommandPath
}
function InitApp(){
	#Determine the environment that we're currently in.
	$configFile = "$(Get-ScriptDirectory)\ESConfig.xml"
	[xml]$ESConfig =  Get-Content $configFile
	
	
	$MachineName = $env:COMPUTERNAME
	$DEVServers  = (($ESConfig.ENV.DEV.DNS.servers  | Select-String $MachineName | %{$_.Line.Split(",")}) -is [system.object])
	$QAServers   = (($ESConfig.ENV.QA.DNS.servers   | Select-String $MachineName | %{$_.Line.Split(",")}) -is [system.object])
	$PRODServers = (($ESConfig.ENV.PROD.DNS.servers | Select-String $MachineName | %{$_.Line.Split(",")}) -is [system.object])
	
	if ($DEVServers -eq $true)
	{
		$global:ENVProfile = $ESConfig.ENV.DEV
	}
	elseif($QAServers -eq $true)
	{
		$global:ENVProfile = $ESConfig.ENV.QA
	}
	elseif($PRODServers -eq $true)
	{
		$global:ENVProfile = $ESConfig.ENV.PROD
	}

	

    $global:ESUrl                 = $global:ENVProfile.SITE.url
	$global:ESServiceName         = $global:ENVProfile.Services.ESServiceName
    $global:KibanaSerivceName     = $global:ENVProfile.Services.KibanaServiceName
    $global:ClusterDiagnosticPath = $global:ENVProfile.Diagnostic.FolderPath
    $global:DiagnosticCommand     = $global:ENVProfile.Diagnostic.ExecuteCommand
    $global:RestoreClusterState   = $global:ENVProfile.Cluster.RestoreState

    # Add logic to check if Kibana and\or ElasticSearch is running and reachable. Display the outputs to the user when the interface starts.
    try
    {
        Write-Host "Checking Cluster Status....."
        GetClusterCoreFeatures
        $Url =  $global:ESUrl +"/_cluster/health?pretty"
        # Get the cluster status health
        $global:ClusterInitState = Invoke-RestMethod -Method GET -Uri $Url -cred $global:UserCredentials
        Write-Host "---------------------------"
        Write-Host "ElasticSearch Current State"
        Write-Host "---------------------------"
        Write-Host "Cluster Name: $($global:ClusterInitState.cluster_name.ToUpper())" -Foreground $global:ClusterInitState.status
        Write-Host "Health Status: $($global:ClusterInitState.status.ToUpper())" -Foreground $global:ClusterInitState.status
    }
    catch
    {
        Write-Host "---------------------------"
        Write-Host "ElasticSearch Current State"
        Write-Host "---------------------------"
        Write-Host "Your cluster is currently down... Try restarting ElasticSearch (step 8)" -Foreground Yellow
    }

}
function DisplayClusterState(){
    if($global:ClusterInitState -ne "")
    {
        Write-Host "---------------------------"
        Write-Host "ElasticSearch Current State"
        Write-Host "---------------------------"
        Write-Host "Cluster Name: $($global:ClusterInitState.cluster_name.ToUpper())" -Foreground $global:ClusterInitState.status
        Write-Host "Health Status: $($global:ClusterInitState.status.ToUpper())" -Foreground $global:ClusterInitState.status
        Write-Host "Number Of Nodes: $($global:ClusterInitState.number_of_nodes)" -Foreground $global:ClusterInitState.status
        Write-Host "Number of Data Nodes: $($global:ClusterInitState.number_of_data_nodes)" -Foreground $global:ClusterInitState.status
        Write-Host "Number of Data Nodes: $($global:ClusterInitState.number_of_data_nodes)" -Foreground $global:ClusterInitState.status
        Write-Host "Active Primary Shards: $($global:ClusterInitState.active_primary_shards)" -Foreground $global:ClusterInitState.status
        Write-Host "Active Shards: $($global:ClusterInitState.active_shards)" -Foreground $global:ClusterInitState.status
        Write-Host "Relocating Shards: $($global:ClusterInitState.relocating_shards)" -Foreground $global:ClusterInitState.status
        Write-Host "Initializing Shards: $($global:ClusterInitState.initializing_shards)" -Foreground $global:ClusterInitState.status
        Write-Host "Unassigned Shards: $($global:ClusterInitState.unassigned_shards)" -Foreground $global:ClusterInitState.status
        Write-Host "Delayed Unassigned Shards: $($global:ClusterInitState.delayed_unassigned_shards)" -Foreground $global:ClusterInitState.status
        Write-Host "Number of Pending Tasks: $($global:ClusterInitState.number_of_pending_tasks)" -Foreground $global:ClusterInitState.status
        Write-Host "Number of In Flight Fetch: $($global:ClusterInitState.number_of_in_flight_fetch)" -Foreground $global:ClusterInitState.status
        Write-Host "Task Max Waiting in queue milliseconds: $($global:ClusterInitState.task_max_waiting_in_queue_millis)" -Foreground $global:ClusterInitState.status
        Write-Host "Active Shards in Percent Format: $($global:ClusterInitState.active_shards_percent_as_number)" -Foreground $global:ClusterInitState.status
    }

    else
    {
        Write-Host "!!!! Your cluster is currently down !!!!" -Foreground Yellow
    }
}
function Main(){
    #RunAsAdmin
	InitApp
    do
    {
		Write-Host ""
		Write-Host "*********************************************************"
        Write-Host "** Welcome to ElasticSearch and Kibana Management Tool **" -ForegroundColor Green
		Write-Host "*********************************************************"
        Write-Host ""
        #DisplayClusterState
        #Write-Host ""
        Write-Host "Please choose an action to execute"
		Write-Host ""
        #Write-Host "1.  Deploy your .jks file to your ElasticSearch Shield folder"
        Write-Host "1.  **** STOP CLUSTER INDEXING ****" -ForegroundColor Green
		Write-Host "2.  **** START CLUSTER INDEXING ****" -ForegroundColor Green
        Write-Host "3.  **** EXECUTE QUERY SYNCH FLUSH ****" -ForegroundColor White
        Write-Host "4.  **** DISABLE SHARD ALLOCATION ****" -ForegroundColor Yellow
		Write-Host "5.  **** ENABLE SHARD ALLOCATION ****" -ForegroundColor Yellow
        Write-Host "6.  **** STOP ELASTICSEARCH ****" -ForegroundColor Green
        Write-Host "7.  **** START ELASTICSEARCH ****" -ForegroundColor Green
		Write-Host "8.  **** RESTART ELASTICSEARCH ****" -ForegroundColor Green
		Write-Host "9.  **** STOP KIBANA ****" -ForegroundColor Yellow
        Write-Host "10. **** START KIBANA ****" -ForegroundColor Yellow
        Write-Host "11. **** RESTART KIBANA ****" -ForegroundColor Yellow
        Write-Host "12. **** GET CLUSTER CURRENT HEALTH ****" -ForegroundColor Green
        Write-Host "13. **** EXIT :( ****" -ForegroundColor White
        Write-Host "" -ForegroundColor Green
        $SelectStep = Read-Host "From the list of actions above, which step do you want to start"
        switch($SelectStep)
        {
            #1  { CopyFile }
			#Disable indexing on the cluster.
            1{ DisableClusterIndexing }     
			#Enable cluster indexing.
			2{ EnableClusterIndexing }      
			#Execute Query Sync Flushed.
			3{ ExecuteQuerySynchFlushed }   
			#Disable shard allocation.
			4{ DisableShardAllocation }     
			#Start Shard Allocation.
			5{ EnableShardAllocation }      
			#Stop ElasticSearch service.
			6 { 
				if($global:IsKibanaMachine -eq $false){
				   StopElasticSearchService 
				}
				else{
					Write-Host "*************************************************************************" -ForegroundColor Yellow
					Write-Host "**** This machine does not have the ElasticSearch serivce installed. ****" -ForegroundColor Red
					Write-Host "*************************************************************************" -ForegroundColor Yellow
				}
			}   
			#Start ElasticSearch service.
            7 { 
				if($global:IsKibanaMachine -eq $false){
				   StartElasticSearchService 
				}
				else{
					Write-Host "*************************************************************************" -ForegroundColor Yellow
					Write-Host "**** This machine does not have the ElasticSearch serivce installed. ****" -ForegroundColor Red
					Write-Host "*************************************************************************" -ForegroundColor Yellow
				}
			}
			#Restart ElasticSearch service  
            8{                            
			   
               if($global:IsKibanaMachine -eq $false){
				   StopElasticSearchService
				   StartElasticSearchService 
				}
				else{
					Write-Host "*************************************************************************" -ForegroundColor Yellow
					Write-Host "**** This machine does not have the ElasticSearch serivce installed. ****" -ForegroundColor Red
					Write-Host "*************************************************************************" -ForegroundColor Yellow
				}
			}
			#Stop Kibana Service
			9 { 
				if($global:IsKibanaMachine -eq $true){
				   StopKibanaService 
				}
				else{
					Write-Host "******************************************************************" -ForegroundColor Yellow
					Write-Host "**** This machine does not have the Kibana serivce installed. ****" -ForegroundColor Red
					Write-Host "*******************************************************************" -ForegroundColor Yellow
				} 
			}
			#Start Kibana Service
            10 { 
				if($global:IsKibanaMachine -eq $true){
				   StartKibanaService 
				}
				else{
					Write-Host "******************************************************************" -ForegroundColor Yellow
					Write-Host "**** This machine does not have the Kibana serivce installed. ****" -ForegroundColor Red
					Write-Host "*******************************************************************" -ForegroundColor Yellow
				} 
			} 
			#Restart Kibana Service 
			11 { 
				if($global:IsKibanaMachine -eq $true){
				   StopKibanaService
				   StartKibanaService 
				}
				else{
					Write-Host "******************************************************************" -ForegroundColor Yellow
					Write-Host "**** This machine does not have the Kibana serivce installed. ****" -ForegroundColor Red
					Write-Host "*******************************************************************" -ForegroundColor Yellow
				}
            }
            #Get Cluster diagnotic report
            12
            {
                DisplayClusterState
            }
            default { Write-Host "" }
        }
        
    }While ($SelectStep -ne 13)
    Write-Host ""
    Write-Host "Good Bye !!!!" -ForegroundColor Green
    Write-Host ""
}
Main