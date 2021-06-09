function createProject{
    param(
        [String]$org,
        [String]$projectName,
        [String]$process,
        [String]$sourceControl,
        [String]$visibility
    )


    Write-Host "`nCreating project with name $($projectName) . . . " 
    $project = az devops project create --org $org --name $projectName --process $process --source-control $sourceControl --visibility $visibility -o json | ConvertFrom-Json
    Write-Host "Created project with name $($project.name) and Id $($project.id)"
    return $project.id
}

function createRepo{
    param(
        [String]$org,
        [String]$projectID,
        [String]$repoName
    )

    Write-Host "`nCreating repository with name $($repoName) . . . " 
    $repo = az repos create --org $org -p $projectID --name $repoName -o json | ConvertFrom-Json
    Write-Host "Created repository with name $($repo.name) and Id $($repo.id)"
    return $repo.id
}

function createTeam {
    param (
        [string]$teamName,
        [string]$org,
        [string]$projectID
    )
    Write-Host "`nCreating team with name $($teamName) . . . " 
    $createTeam = az devops team create --name $teamName  --org $org -p $projectID -o json | ConvertFrom-Json
    Write-Host "Created team with name $($createTeam.name) and Id $($createTeam.id)"
    return $createTeam.id
}

function addMember {
    param (
        [string]$teamName,
        [string]$memberId
    )
    $listGroups = az devops security group list --org $org -p $projectID -o json | ConvertFrom-Json
    
    foreach ($grp in $listGroups.graphGroups) {
        if ($grp.displayName -eq $teamName) {
            Write-Host "Adding member $memberId"
            az devops security group membership add --group-id $grp.descriptor --member-id $memberId
            Write-Host "Team member $memberId added"
        }
    }
}

$org = 'https://dev.azure.com/jordankelley105/'
$teamName = 'TestingTeam'

# scaffolding
$projectId = createProject -org $org -projectName 'TestingProject' -process 'Agile' -sourceControl 'git' -visibility 'private'

createRepo -org $org -projectID $projectId -repoName 'TestingRepo'

createTeam -teamName 'TestingTeam' -org $org -projectID $projectId

addMember -teamName $teamName -memberId 'jordan.kelley105@gmail.com'