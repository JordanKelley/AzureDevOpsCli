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
        [string] $org, 
        [string] $projectId,
        [string] $teamName,
        [string] $groupName
    )

    if ([string]::IsNullOrEmpty($teamName)) {
        $createdGroup = az devops security group create --org $org -p $projectId --name $groupName -o json | ConvertFrom-Json
        Write-Host "`nCreated new group with name $($name)."
        return $createdGroup
    }
    else {
        $listGroups = az devops security group list --org $org -p $projectID -o json | ConvertFrom-Json
        foreach ($grp in $listGroups.graphGroups) {
            if ($grp.displayName -eq $teamName) {
                $createdGroup = az devops security group create --org $org -p $projectId --name $groupName --groups $grp.descriptor -o json | ConvertFrom-Json
                Write-Host "`nCreated new group with name $($groupName) and added to the team $teamName."
                return $createdGroup
            }
        }
    }
}

function updateGroupToAdmin {
    param (
        [string] $org,
        [string] $projectId,
        [string] $teamId,
        [string] $adminGroupDescriptor
    )
    $securityToken = $projectID + '\' + $teamID 

    #display current permissions
    $showIdentityPermissions = az devops security permission show --org $org --id 5a27515b-ccd7-42c9-84f1-54c998f03866 --token $securityToken --subject $adminGroupDescriptor -o json | ConvertFrom-Json
    Write-Host "Current permissions for this group"
    displayPermissions -permissionsResponse $showIdentityPermissions

    #update permissions to manage : Adding team admins is equivalent to giving them manage permissions (i.e bit 31)
    az devops security permission update --allow-bit 31 --org $org --id 5a27515b-ccd7-42c9-84f1-54c998f03866 --token $securityToken --subject $adminGroupDescriptor -o json | ConvertFrom-Json
    Write-Host "`nGiving admins permissions to the requested group. Updated permissions:"

    $showIdentityPermissions = az devops security permission show --org $org --id 5a27515b-ccd7-42c9-84f1-54c998f03866 --token $securityToken --subject $adminGroupDescriptor -o json | ConvertFrom-Json
    displayPermissions -permissionsResponse $showIdentityPermissions
}

function createTeamArea {
    param (
        [string]$org,
        [string]$projectId,
        [string]$areaName
    )

    $createAreasForTeam = az boards area project create --name $areaName --org $org --project $projectId -o json | ConvertFrom-Json
    Write-Host "`nNew area created : $($createAreasForTeam.name) with id : $($createAreasForTeam.id)"
}

function configureDefaultArea {
    param (
        [string] $org,
        [string] $projectId,
        [string] $teamId,
        [string] $defaultAreaPath
    )
    az boards area team add --path $defaultAreaPath --set-as-default --team $teamId --org $org --project $projectId -o json | ConvertFrom-Json
    Write-Host "Default area changed to: $defaultAreaPath"
}

function get_token{
    param(
        [String]$iterationsNodeID,
        [String]$rootIterationID,
        [String]$childIterationID
    )
    $rootStr = 'vstfs:///Classification/Node/'
    $tokenStr = ''
    if($iterationsNodeID)
    {
        $tokenStr = $rootStr + $iterationsNodeID
        if($rootIterationID)
        {
            $tokenStr = $tokenStr + ':' + $rootStr + $rootIterationID
            if($childIterationID)
            {
                $tokenStr = $tokenStr + ':' + $rootStr + $childIterationID
            }
            return $tokenStr
        }
    }
    else {
        return $null
    }
}

function setPermissions{
    param(
        [String]$org,
        [String]$subject,
        [String]$tokenStr,
        [Int]$allowBit,
        [Int]$denyBit
    )
    # boards iterations namespace id
    $namespaceId = 'bf7bfa03-b2b7-47db-8113-fa2e002cc5b1'
    
    $aclList = az devops security permission list --org $org --subject $subject --id $namespaceId -o json | ConvertFrom-Json
    foreach($acl in $aclList){
        if ($($acl.token) -contains $tokenStr)
        {
            # Show permissions
            $displayPermissions = az devops security permission show --org $org --id $namespaceId --subject $subject --token $tokenStr -o json | ConvertFrom-Json
            Write-Host "`nCurrent iterations related permissions for admin group :"
            displayPermissions -permissionsResponse $displayPermissions

            # Update permissions
            if($allowBit)
            {
                $updatePermissions = az devops security permission update --org $org --id $namespaceId --subject $subject --token $tokenStr --allow-bit $allowBit -o json | ConvertFrom-Json    
            }

            if($denyBit)
            {
                $updatePermissions = az devops security permission update --org $org --id $namespaceId --subject $subject --token $tokenStr --deny-bit $denyBit -o json | ConvertFrom-Json    
            }
            
            $displayPermissions = az devops security permission show --org $org --id $namespaceId --subject $subject --token $tokenStr -o json | ConvertFrom-Json
            Write-Host "Updated iterations related permissions for admin group :"
            displayPermissions -permissionsResponse $displayPermissions
        }
    }
}

function projectLevelIterationsSettings {
    param (
        [string] $org,
        [string] $projectId,
        [string] $rootIterationName,
        [string] $subject,
        [int] $allow,
        [int] $deny,
        [string[]] $childIterationNamesList
    )
    # Project level iterations
    $projectRootIterationList = az boards iteration project list --org $org --project $projectID -o json | ConvertFrom-Json
    $iterationsNodeID = $projectRootIterationList.identifier

    $projectRootIterationCreate = az boards iteration project create --name $rootIterationName --org $org --project $projectID -o json | ConvertFrom-Json
    if ($projectRootIterationCreate) {
        Write-Host "`nRoot Iteration created with name: $($projectRootIterationCreate.name)"
        foreach ($entry in $childIterationNamesList) {
            $childIterationName = $rootIterationName + ' ' + $entry.ToString()
            #$projectRootIterationCreate
            $projectChildIterationCreate = az boards iteration project create --name $childIterationName --path $projectRootIterationCreate.path --org $org --project $projectID -o json | ConvertFrom-Json
            Write-Host "Child Iteration created with name: $($projectChildIterationCreate.name)"
        }

        # Add permissions at root iterations
        $rootIterationToken = get_token -iterationsNodeID $iterationsNodeID -rootIterationID  $($projectRootIterationCreate.identifier)
        $updatePermissions = setPermissions -org $org -tokenStr $rootIterationToken -subject $subject -allowBit $allow -denyBit $deny
    }
    return $projectRootIterationCreate.identifier
}

function SelectObject([object]$inputObject, [string]$propertyName) {
    $objectExists = Get-Member -InputObject $inputObject -Name $propertyName

    if ($objectExists) {
        return $inputObject | Select-Object -ExpandProperty $propertyName
    }
    return $null  
}

function printBacklogLevels([object]$boardsTeamSettings) {
    if ($boardsTeamSettings) {
        $epics = SelectObject -inputObject $boardsTeamSettings.backlogVisibilities -propertyName Microsoft.EpicCategory
        Write-Host "Epics: $epics"
        
        $features = SelectObject -inputObject $boardsTeamSettings.backlogVisibilities -propertyName Microsoft.FeatureCategory
        Write-Host "Features: $features"
        
        $requirements = SelectObject -inputObject $boardsTeamSettings.backlogVisibilities -propertyName Microsoft.RequirementCategory
        Write-Host "Stories: $requirements"
        
        $days = $boardsTeamSettings.workingDays
        Write-Host "Working days : $days"
    }
}

function setUpGeneralBoardSettings {
    param(
        [String]$org,
        [String]$projectID,
        [String]$teamID,
        [Bool]$epics,
        [Bool]$stories,
        [Bool]$features
    )

    # Team boards settings
    $currentBoardsTeamSettings = az devops invoke --org $org --area work --resource teamsettings --api-version '5.0' --http-method GET --route-parameters project=$projectID team=$teamID  -o json | ConvertFrom-Json
    Write-Host "`nCurrent general team configurations"
    "Current backlog navigation levels"
    printBacklogLevels -boardsTeamSettings $currentBoardsTeamSettings

    #update these settings
    New-Item -ItemType Directory -Force -Path .\InvokeRequests\
    $invokeRequestsPath = Join-Path $PSScriptRoot \InvokeRequests\
    $contentFileName = $invokeRequestsPath + 'updateTeamConfig.txt'
    $contentToStoreInFile = [System.Text.StringBuilder]::new()
    [void]$contentToStoreInFile.Append( "{")

    if ($epics -or $stories -or $features) {
        [void]$contentToStoreInFile.Append(  "`"backlogVisibilities`" : { " )
        if ($epics -eq $True) {
            [void]$contentToStoreInFile.Append(  "`"Microsoft.EpicCategory`" : true " )
        }
        else {
            [void]$contentToStoreInFile.Append(  "`"Microsoft.EpicCategory`" : false " )
        }

        if ($features -eq $True) {
            [void]$contentToStoreInFile.Append(  ",`"Microsoft.FeatureCategory`" : true " )
        }
        else {
            [void]$contentToStoreInFile.Append(  ",`"Microsoft.FeatureCategory`" : false " )
        }
        
        if ($stories -eq $True) {
            [void]$contentToStoreInFile.Append(  ",`"Microsoft.RequirementCategory`" : true " )
        }
        else {
            [void]$contentToStoreInFile.Append(  ",`"Microsoft.RequirementCategory`" : false " )
        }

        [void]$contentToStoreInFile.Append( "}" ) 
    }
    [void]$contentToStoreInFile.Append( "}" )
    Set-Content -Path $contentFileName -Value $contentToStoreInFile.ToString()
    
    $updatedBoardsTeamSettings = az devops invoke --org $org --area work --resource teamsettings --api-version '5.0' --http-method PATCH --route-parameters project=$projectID team=$teamID --in-file $contentFileName -o json | ConvertFrom-Json
    "Updated backlog navigation levels"
    printBacklogLevels -boardsTeamSettings $updatedBoardsTeamSettings
}

function setUpTeamIterations {
    param(
        [String]$org,
        [String]$projectName,
        [String]$teamID
    )

    # show backlog iteration command
    $backlogIterationDetails = az boards iteration team show-backlog-iteration --team $teamID --org $org --project $projectName -o json | ConvertFrom-Json
    $depthParam = '1'
    $backlogIterationPath = $backlogIterationDetails.backlogIteration.path
    Write-Host "`nTeam Iterations Configuration"
    # Format iteration path to include project name and structure type
    $backlogIterationPath = '\' + $projectName + '\Iteration\' + $backlogIterationPath 
    $rootIteration = az boards iteration project list --path $backlogIterationPath --project $projectName --org $org --depth $depthParam -o json | ConvertFrom-Json
    if ($rootIteration.hasChildren -eq $True) {
        foreach ($child in $rootIteration.children) {
            $getProjectTeamIterationID = $child.identifier
            # add this child iteration to the given team
            $addTeamIteration = az boards iteration team add --team $teamID --id $getProjectTeamIterationID  --project $projectName --org $org -o json | ConvertFrom-Json
            Write-Host "Team iteration added with ID : $($addTeamIteration.id) and name:$($child.name)"
        }
    }
    
}

$org = 'https://dev.azure.com/jordankelley105/'
$teamName = 'TestingTeam'
$projectName = 'TestingProject'

# scaffolding
$projectId = createProject -org $org -projectName $projectName -process 'Agile' -sourceControl 'git' -visibility 'private'

createRepo -org $org -projectID $projectId -repoName 'TestingRepo'

$createdTeam = createTeam -teamName 'TestingTeam' -org $org -projectID $projectId

addMember -teamName $teamName -memberId 'jordan.kelley105@gmail.com'

$teamAdminGroupName = $teamName + ' Admins'
$adminGroup = createGroup -org $org -projectId $projectId -teamName $teamName -groupName $teamAdminGroupName

updateGroupToAdmin -org $org -projectId $projectId -teamId $createdTeam.id -adminGroupDescriptor $adminGroup.descriptor

createTeamArea -org $org -projectId $projectId -areaName $teamName

$areaPath = $projectName + '\' + $teamName
configureDefaultArea -org $org -projectId $projectId -teamId $createdTeam.id -defaultAreaPath $areaPath

# Configure project level iterations with this group/team and grant permissions for admins group
$projectIterationNameForThisTeam = $teamName + ' iteration' 
$childIterationNamesList = @('ChildIteration1', 'ChildIteration2')
$rootIterationId = projectLevelIterationsSettings -org $org -projectID $projectID -rootIterationName $projectIterationNameForThisTeam -subject $adminGroup.descriptor -allow 7 -childIterationNamesList $childIterationNamesList

if ($rootIterationId) {
    #set backlog iteration ID
    $setBacklogIteration = az boards iteration team set-backlog-iteration --id $rootIterationId --team $createdTeam.id --org $org -p $projectID -o json | ConvertFrom-Json 
    Write-Host "`nSetting backlog iteration to : $($setBacklogIteration.backlogIteration.path)"
    # Boards General Settings
    setUpGeneralBoardSettings -org $org -projectID $projectId -teamID $createdTeam.id -epics $true -stories $true -features $true 

    # Add child iterations of backlog iteration to the given team
    setUpTeamIterations -org $org -projectName $projectName -teamID $createdTeam.id
}

# clean up temp files for invoke requests
Remove-Item -path .\InvokeRequests\ -recurse