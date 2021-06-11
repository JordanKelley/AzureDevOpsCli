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
    return $createTeam
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

function displayPermissions{
    param([object]$permissionsResponse)
    
    foreach($acl in $permissionsResponse)
    {
            $ace = $acl.acesDictionary
            $ace_key = $ace | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name
            $ace_value= $ace.$ace_key
            $permissionsList =   $($ace_value.resolvedPermissions)
            foreach($perm in $permissionsList)
            {
                Write-Host "$($perm.displayName) [$($perm.bit)] , $($perm.effectivePermission)"
            }
    }
}

function createGroup {
    param (
        [string] $groupDescriptor,
        [string] $groupName,
        [string] $org, 
        [string] $projectId,
        [string] $name
    )

    if ([string]::IsNullOrEmpty($groupDescriptor)) {
        $createdGroup = az devops security group create --org $org -p $projectID --name $name -o json | ConvertFrom-Json
        Write-Host "`nCreated new group with name $($name)."
        return $createdGroup
    }
    else {
        $createdGroup = az devops security group create --org $org -p $projectID --name $name --groups $groupDescriptor -o json | ConvertFrom-Json
        Write-Host "`nCreated new group with name $($name) and added to the team $groupName."
        return $createdGroup
    }
}

function addTeamAdmins {
    param (
        [string] $org,
        [string] $projectId,
        [string] $teamId,
        [string] $teamName
    )

    $listGroups = az devops security group list --org $org -p $projectID -o json | ConvertFrom-Json

    foreach ($grp in $listGroups.graphGroups) {
        if ($grp.displayName -eq $teamName) {
            $teamAdminGroupName = $teamName + ' Admins'
            
            $createdGroup = createGroup -groupDescriptor $grp.descriptor -groupName $grp.displayName -org $org -projectId $projectId -name $teamAdminGroupName

            $securityToken = $projectID + '\' + $teamID 

            #display current permissions
            $showIdentityPermissions = az devops security permission show --org $org --id 5a27515b-ccd7-42c9-84f1-54c998f03866 --token $securityToken --subject $createdGroup.descriptor -o json | ConvertFrom-Json
            Write-Host "Current permissions for this group"
            displayPermissions -permissionsResponse $showIdentityPermissions

            #update permissions to manage : Adding team admins is equivalent to giving them manage permissions (i.e bit 31)
            az devops security permission update --allow-bit 31 --org $org --id 5a27515b-ccd7-42c9-84f1-54c998f03866 --token $securityToken --subject $createdGroup.descriptor -o json | ConvertFrom-Json
            Write-Host "`nGiving admins permissions to the requested group. Updated permissions:"

            $showIdentityPermissions = az devops security permission show --org $org --id 5a27515b-ccd7-42c9-84f1-54c998f03866 --token $securityToken --subject $createdGroup.descriptor -o json | ConvertFrom-Json
            displayPermissions -permissionsResponse $showIdentityPermissions
        }
    }
}

$org = 'https://dev.azure.com/jordankelley105/'
$teamName = 'TestingTeam'

# scaffolding
$projectId = createProject -org $org -projectName 'TestingProject' -process 'Agile' -sourceControl 'git' -visibility 'private'

createRepo -org $org -projectID $projectId -repoName 'TestingRepo'

$createdTeam = createTeam -teamName 'TestingTeam' -org $org -projectID $projectId

addMember -teamName $teamName -memberId 'jordan.kelley105@gmail.com'

addTeamAdmins -org $org -projectId $projectId -teamId $createdTeam.id -teamName $teamName