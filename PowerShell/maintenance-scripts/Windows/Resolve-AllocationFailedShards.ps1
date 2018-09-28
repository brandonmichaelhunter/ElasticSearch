<#
.SYNOPSIS
 Resolve-AllocationFailedShards.ps1 is a script that will resolve indexes that have a shard that failed to be allocated on an particualr index. 
.DESCRIPTION
 Use this script as a solution to resolve indicies that unassigned shards where the unassigned.reason value is equal to ALLOCATION_FAILED'. 
 To identify if you have unassigned shards in your cluster navigate to the cluster's health api using the following url https://<ESInstaneName>/_cluster/health?pretty. 
 Within the return response, you should see a field called unassigned_shards, which will tell the number of unassigned shards you have.
 To identify the reason why you have unassigned shards within your cluster, then navigate to the shard api url https://<ESInstaneName>/_cat/shards?h=index,shard,prirep,state,unassigned.reason&v .
 With the return response you will see a column called 'unassigned.reason' which provides the reason why a shard was unassigned.
 For a complete list of reasons for unassigned shards, check out this link - https://www.elastic.co/guide/en/elasticsearch/reference/current/cat-shards.html

.PARAMETER Url
 Url refers to url for you ElasticSearch cluster.
.PARAMETER Username
 Refers to a username for an account that has the ability to modify cluster and indices settings.
.PARAMETER Password
 Refers to a password for an account that has the ability to modify cluster and indices settings.
.PARAMETER Index
 Refers to the name of the index that has unassigned shards with a unassigned.reason value of ALLOCATION_FAILED
.PARAMETER ReplicaShardCount
 Represents the replica count for an index.

.EXAMPLE

.\Set-AllocationFailedShards -Url 'https://clusterurl:9200' -Username 'elastic' -Password 'changeme' -IndexName 'twitter-2018.02.10' -ReplicaShardCount 1

#>

[CmdletBinding(PositionalBinding=$false)]Param(
                            [Parameter(Mandatory=$True,Position=0)][string] $Url,   [Parameter(Mandatory=$True,Position=1)][string] $Username,
                            [Parameter(Mandatory=$True,Position=2)][string] $Password,[Parameter(Mandatory=$True,Position=3)][string] $IndexName,
                            [Parameter(Mandatory=$True,Position=5)][int] $ReplicaShardCount)

    if($ReplicaShardCount -eq 0)
    {
        $MaxReplicas = 1
    }

    try
    {
        Write-Host "Resolving Unassigned Shard - ALLOCATION_FAILED on index $($IndexName)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host " **** Setting the number_of_replicas property to 0 on index $($IndexName) **** " -ForegroundColor Yellow
        $esUrl = "$($Url)/$($IndexName)/_settings" 
        $cmd = '{ "number_of_replicas": 0 }'
        $creds    = $null
        $pwd      = ConvertTo-SecureString $Password -AsPlainText -Force
        $creds    = New-Object Management.Automation.PSCredential ($Username, $pwd)
        $response = Invoke-RestMethod -Method PUT -Uri $esUrl -Body $cmd -cred $creds
        if($response.acknowledged -eq $True)
        {
            Write-Host " **** Setting the number_of_replicas property to 0 on index $($IndexName) has been completed **** " -ForegroundColor Green
            Write-Host ""
            Write-Host " **** Setting the number_of_replicas property to its original value $($ReplicaShardCount) on index $($IndexName) **** " -ForegroundColor Yellow
            # Set the number of replicas for the index to the $ReplicaShardCount value
            $cmd = '{ "number_of_replicas": '+ $ReplicaShardCount+' }'
            $creds    = $null
            $pwd      = ConvertTo-SecureString $Password -AsPlainText -Force
            $creds    = New-Object Management.Automation.PSCredential ($Username, $pwd)
            $response = Invoke-RestMethod -Method PUT -Uri $esUrl -Body $cmd -cred $creds
            if($response.acknowledged -eq $True){
                Write-Host " **** Setting the number_of_replicas property to its original value $($ReplicaShardCount) on index $($IndexName) has been completed **** " -ForegroundColor Green
            }
            else{
                throw "There was an error setting the number_of_replicas to 1 on index $($IndexName)" 
            }
        }
        else
        {
            throw "There was an error setting the number_of_replicas to 0 on index $($IndexName)"
        }
    }
    catch
    {
      Write-Host "Item Name: $($_.Exception.ItemName)" -Foreground Red
      Write-Host "Exception: $($_.Exception.Message)" -Foreground Red
    }