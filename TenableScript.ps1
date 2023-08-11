Function GetAgentObject() {
    Param (
        [parameter(Mandatory=$true)][string]$agentName
    )

    #$agentName -match "\d+$"
    #$number = $Matches[0]
    $rest = $agentName -replace "\d+$" , ''
    $len = $rest.length - 1

    return New-Object -TypeName PSObject -Property @{
        #number = $number;
        type= $rest.Substring($len);
        name =  $rest.Substring(0, $len)
    }
}

#authorization and headers
$headers = @{
    'Accept' = 'application/json'
    'X-ApiKeys' = 'accessKey=xxxxxxxxx;secretKey=xxxxxxxxxxx'
}

#Agent variables 
#-------------------------
#connects to the api endpoint and filters to only get the agents that are not attatched to a group using the f=groups:eq:-1
$apiEndpointAgents = "https://cloud.tenable.com/scanners/1/agents?f=groups:eq:-1&limit=5000"

#stores all of the unassigned agents in an array/variable
$UnassignedAgents = Invoke-RestMethod -Uri $apiEndpointAgents -Headers $headers

#Group Variables 
#-------------------------
#connects to the api and grabs all of the groups within a scanner
$apiEndpointGroups = 'https://cloud.tenable.com/scanners/d1vnessus001/agent-groups'

#stores all of the groups withing a certain scanner in an array/variable 
$GroupsInScanner = Invoke-WebRequest -Uri $apiEndpointGroups -Method GET -Headers $headers 

#Loop to add all of the unassigned agents to their respective groups 
#-------------------------

$agents = $UnassignedAgents.agents `
    | Select-Object @{N='agentID';E={$_.id}}, `
         @{Expression={(GetAgentObject($_.name)).type}; `
        Label="type"}, `
         @{Expression={(GetAgentObject($_.name)).name}; `
        Label="name"} #`
$agents = $agents | Where-Object {$_.type -eq 'D' -or $_.type -eq 'L' -or $_.type -eq 'T'}

$groups = ($GroupsInScanner | ConvertFrom-Json).groups `
     | Select-Object @{N='groupID';E={$_.id}}, `
        name

$LinqJoinedData = [System.Linq.Enumerable]::Join(
    $agents,
    $groups,
    [System.Func[Object,string]] {param ($x);$x.name},
    [System.Func[Object,string]]{param ($y);$y.name},
    [System.Func[Object,Object,Object]]{
        param ($x,$y);
        New-Object -TypeName PSObject -Property @{
        Name = $x.Name;
        agentID= $x.agentID;
        groupID = $y.groupID}
    }
)

$ljdArray = [System.Linq.Enumerable]::ToArray($LinqJoinedData)

#will add the agents to the group 
$ljdArray | ForEach-Object {write-host "Agent ID: $($_.agentID) has been assigned to group ID: $($_.groupID)"
Invoke-WebRequest -Uri "https://cloud.tenable.com/scanners/148573/agent-groups/$($_.groupID)/agents/$($_.agentID)" -Method PUT -Headers $headers

}
