Param($ResourceGroup,$GalleryName)

$maxToDelete = 20
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
            Write-Verbose -Message "Deletinig image version: --gallery-name $gallery --gallery-image-definition $imageDef --gallery-image-version $version" -Verbose
            az sig image-version delete --resource-group $ResourceGroup --gallery-name $gallery --gallery-image-definition $imageDef --gallery-image-version $version
        }
        break
    } else {
        Write-Verbose "skipping $imageDef - $count" -Verbose
    }
}