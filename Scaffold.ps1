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

# scaffolding
createProject -org 'https://dev.azure.com/jordankelley105/' -projectName 'TestingScript' -process 'Agile' -sourceControl 'git' -visibility 'private'