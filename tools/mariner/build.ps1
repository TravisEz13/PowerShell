# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

param(
    [ValidateSet("build", "run")]
    [string[]]
    $Task = "build",
    [string]
    $Tag = "ps-mariner",
    [switch]
    $NoCache,
    [switch]
    $Pull,
    [string]
    $GitHubOrganization = "PowerShell",
    [ValidateSet("fxdependent-linux-x64","linux-x64")]
    [string]$Runtime = "fxdependent-linux-x64"
)

$fullTag = $Tag+"-"+$Runtime
$packageType = 'rpm-fxdependent'
$extraPackages = ''
if ($Runtime -eq 'linux-x64') {
    $packageType = 'rpm'
} else {
    # package formats:
    # just the package name: dotnet-runtime-x.x
    # versioned : dotnet-runtime-x.x-x.x.x
    # release: dotnet-runtime-x.x-x.x.x-<release>, e.g. dotnet-runtime-7.0-7.0.0-0.1.preview.2.22152.2
    $extraPackages = 'dotnet-runtime-7.0'
}

Foreach ($taskName in $Task) {
    switch ($taskName) {
        "build" {
            $dockerFile = Join-Path $PSScriptRoot -ChildPath "Dockerfile"
            $repoRoot = Split-Path (Split-Path $PSScriptRoot)
            $params = @()
            $params += "--tag", $fullTag
            $params += "--file", $dockerFile
            $params += "--build-arg", "organization=$GitHubOrganization"
            $params += "--build-arg", "runtime=$Runtime"
            $params += "--build-arg", "packageType=$packageType"
            $params += "--build-arg", "extraPackages=$extraPackages"
            if ($NoCache) {
                $params += "--no-cache"
            }

            if ($Pull) {
                $params += "--pull"
            }

            $params += $repoRoot

            Write-Verbose "running docker build $params" -Verbose
            docker build $params
            if ($LastExitCode -ne 0) {
                throw "Failed to build docker image"
            }
        }
        "run" {
            $dockerFile = Join-Path $PSScriptRoot -ChildPath "Dockerfile"
            $repoRoot = Split-Path (Split-Path $PSScriptRoot)
            [int]$size = (docker inspect $fullTag | convertfrom-json).Size / 1MB
            $history = (docker history $fullTag --format='{{json .}}') | ConvertFrom-Json
            $base = $history | Where-Object { $_.Comment -like "Imported*" }
            $baseSize = $base.Size
            ($pwshSize,$depsSize) = $history | Where-Object { $_.CreatedBy -like 'RUN *' } | Select-Object -ExpandProperty Size
            Write-Verbose "Docker image size: $size MB; pwsh: $pwshSize, deps: $depsSize, base: $baseSize" -Verbose
            docker run --rm -it $fullTag
        }
    }
}
