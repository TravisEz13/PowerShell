Param($ResourceGroup,$GalleryName)

$throttleLimit = 7
$maxToDelete = 100
$versionsToKeep = 10
$galleries = az sig list --resource-group $ResourceGroup | convertfrom-json | Select-Object -ExpandProperty Name
$images = @()
foreach($gallery in $galleries) {
    az sig image-definition list --gallery-name $GalleryName --resource-group $ResourceGroup | convertfrom-json | Select-Object -ExpandProperty Name | ForEach-Object {
        $images += @{
            Gallery=$gallery
            ImageDefinition = $_
        }
    }
}
foreach($image in $images){
    $gallery=$image.Gallery
    $imageDef = $image.ImageDefinition
    $versions = @(az sig image-version list --resource-group $ResourceGroup --gallery-name $gallery --gallery-image-definition $imageDef | convertfrom-json)
    $count = $versions.count
    if($count -gt $versionsToKeep) {
        $keepAfter = (get-date).AddDays(-90)
        [int] $toDelete = ($count-$versionsToKeep)/2
        if($toDelete -gt $maxToDelete) {
            $toDelete = $maxToDelete
        }
        Write-Verbose "Deleting at max $toDelete of $count versions and only older than $keepAfter" -verbose
        $oldVersions = $versions  | Foreach-Object {
            $created = $_.publishingProfile.publishedDate
            $_ | Add-Member -NotePropertyName Created -NotePropertyValue $created -PassThru
        } | Where-Object {$_.created -lt $keepAfter} | Sort-Object -Property Created | Select-Object -First $toDelete
        write-verbose "found $($oldVersions.count) versions to delete" -verbose
        $oldVersions | ForEach-Object {

            $version = $_.name
            [PSCustomObject]@{
                Version=$version
                Gallery=$Gallery
                ResourceGroup=$ResourceGroup
                ImageDefinition=$imageDef
            }
        } | ForEach-Object -ThrottleLimit $throttleLimit -Parallel {
            $version = $_.Version
            $Gallery = $_.Gallery
            $ResourceGroup = $_.ResourceGroup

            $ImageDefinition = $_.ImageDefinition

            Write-Host -Message "deleting $imageDefinition - $version" -ForegroundColor DarkGray
            az sig image-version delete --resource-group $ResourceGroup --gallery-name $gallery --gallery-image-definition $imageDefinition --gallery-image-version $version
            if ($lastexitcode -eq 0) {
                Write-Host -Message "deleted $imageDefinition - $version" -ForegroundColor Green
            }
            else {
                Write-Host -Message "failed to delete $imageDefinition - $version" -ForegroundColor Red
            }
        }
    } else {
        Write-Verbose "skipping $imageDef - $count" -Verbose
    }
}