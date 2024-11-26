$dstFolder = "./build/"

# TODO: Check that package.json exists
$packageJson = Get-Content .\package.json -Raw | ConvertFrom-Json

$extensionFilename = $packageJson.name + "-v" + $packageJson.version

if(!(Test-Path -Path $dstFolder)) {
	New-Item -Path $dstFolder -ItemType Directory
}

$destinationPath = $dstFolder + $extensionFilename + ".zip"
$extensionPath = $dstFolder + $extensionFilename + ".aseprite-extension"

Compress-Archive -Path package.json, src\*.lua -DestinationPath $destinationPath

Move-Item -Path $destinationPath -Force -Destination $extensionPath
