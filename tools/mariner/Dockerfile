# syntax = docker/dockerfile:1.4
FROM mcr.microsoft.com/powershell/test-deps:ubuntu-20.04 AS repo
    RUN rm -f /etc/apt/apt.conf.d/docker-clean
    RUN --mount=type=cache,target=/var/cache/apt \
        apt update && apt install -y git

    ARG organization=powershell
    RUN git clone https://github.com/${organization}/powershell.git


    SHELL [ "pwsh", "-c" ]
    WORKDIR /powershell

    # Update build.psm1 from local repo
    COPY *.psm1 /powershell/

    ENV DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
    ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
    ENV POWERSHELL_TELEMETRY_OPTOUT=1

    # Bootstrap
    RUN --mount=type=cache,target=/var/cache/apt \
        import-module ./build.psm1; \
        start-psbootstrap -ErrorAction Stop

FROM repo as binary-build-env

#COPY .* /powershell/
#COPY /src /powershell/src
#COPY tools/buildCommon /powershell/tools/buildCommon
#COPY tools/Xml /powershell/tools/Xml
#COPY /assets /powershell/assets
#COPY *.txt /powershell/
#COPY *.json /powershell/
#COPY *.props /powershell/
#COPY *.stylecop /powershell/
#COPY *.config /powershell/

ENV RELEASE_TAG=v7.3.0-rebuild.98

ARG runtime=fxdependent-linux-x64
ENV RUNTIME=${runtime}

# Build
RUN \
    import-module ./build.psm1; \
    start-psbuild -Configuration Release -clean -Restore -TypeGen -Runtime $env:RUNTIME -Output /psoutput -ReleaseTag $env:RELEASE_TAG -ErrorAction Stop -PSModuleRestore; \
    Save-PSOptions -PSOptionsPath /psoutput/psoptions.json

FROM repo AS package-env

# Bootstrap packaging
RUN --mount=type=cache,target=/var/cache/apt \
    import-module ./build.psm1; \
    start-psbootstrap -package -ErrorAction Stop

# Update packaging module
COPY tools/packaging /powershell/tools/packaging

ENV RELEASE_TAG=v7.3.0-rebuild.98

COPY --from=binary-build-env /psoutput /psoutput
ARG packageType=rpm-fxdependent
# Build package
RUN \
    if(-not(Test-Path /psoutput/*)) {throw "No files found in /psoutput"}; \
    import-module ./build.psm1; \
    import-module ./tools/packaging -ErrorAction Stop ; \
    Restore-PSOptions -PSOptionsPath /psoutput/psoptions.json; \
    start-pspackage -type $env:packageType -ErrorAction Stop -ReleaseTag $env:RELEASE_TAG; \
    if($errors.count) {throw "Failed to package"}; \
    new-item -type directory -path /psrpm -force; \
    Copy-item *.rpm /psrpm/

RUN if(-not(Test-Path -Path /psrpm/*.rpm -ErrorAction Stop)) { exit 1}
RUN \
    import-module ./build.psm1; \
    find-dotnet; \
    dotnet --list-sdks > /psoutput/dotnet-sdks.txt

FROM cblmariner.azurecr.io/base/core:1.0 AS finalImage

# add preview repo for dotnet 7.0 runtime
COPY ./tools/mariner/mariner-microsoft.repo /etc/yum.repos.d/mariner-microsoft.repo

ARG extraPackages=
# install depenecies
RUN --mount=type=cache,target=/var/cache/tdnf \
    tdnf install -y \
        ca-certificates-microsoft \
        \
        # .NET dependencies
        glibc \
        icu \
        krb5 \
        libgcc \
        libstdc++ \
        openssl-libs \
        zlib \
        # du
        coreutils \
        ${extraPackages}

# install powershell
RUN --mount=type=cache,target=/var/cache/tdnf \
    --mount=from=package-env,target=/mnt/pwsh-build,source=/psrpm \
    rpm --install /mnt/pwsh-build/powershell*cm1.x86_64.rpm \
    && ln -s /opt/microsoft/powershell/7-preview/pwsh /usr/bin/pwsh

CMD ["pwsh"]
