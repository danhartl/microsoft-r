Trace-VstsEnteringInvocation $MyInvocation

$scriptRuntime = Get-VstsInput -Name ScriptRuntime
$scriptPath = Get-VstsInput -Name ScriptPath
$inputFiles = (Get-VstsInput -Name InputFiles).Split("`n`r")
$outputFiles = (Get-VstsInput -Name OutputFiles).Split("`n`r")

if((Test-Path(".\MLDeploy.DotNet\MLDeploy.DotNet.dll")) -eq $false) {
  Invoke-WebRequest "https://danhartlsetup.blob.core.windows.net/public/MLDeploy.DotNet.zip" -OutFile MLDeploy.DotNet.zip
  Expand-Archive .\MLDeploy.DotNet.zip
  Remove-Item .\MLDeploy.DotNet.zip
}

[Reflection.Assembly]::LoadFrom("$PSScriptRoot\MLDeploy.DotNet\MLDeploy.DotNet.dll") >$null 2>&1

$ml = New-Object MLDeploy.DotNet.MLDeploy(
    "https://deployr.mrs.microsoft-tst.com",
	"deployruser",
    "Audi@2015Audi@2015")

Write-Host "Create remote session for $scriptRuntime"
$sessionId = $ml.CreateSession($scriptRuntime)
Write-Host "Remote session $sessionId created"

function Push-File([string]$session, [string]$fileName)
{
    Write-Host "Pushing file $fileName to remote session $session"

    if((Test-Path($fileName)) -eq $false) {
        throw ("$fileName not found")
    }
    
    $fileStream = [System.IO.File]::OpenRead($fileName)
    $ml.PushFile($session, $fileStream)
    $fileStream.Close()
}

function Pull-File([string]$session, [string]$fileName, [string]$destinationPath)
{
    Write-Host "Pulling file $fileName from remote session $session to $destinationPath"

    $fileStream = $ml.PullFile($session, $fileName)
    $outputStream = [System.IO.File]::OpenWrite($destinationPath)
    $fileStream.CopyTo($outputStream)
    $fileStream.Close()
    $outputStream.Close()
}

function Load-FileContent([string]$fileName)
{
    $reader = [System.IO.File]::OpenText($fileName)
    $content = $reader.ReadToEnd()
    $reader.Close()
    
    return $content
}

$sourceRoot = $Env:SYSTEM_DEFAULTWORKINGDIRECTORY
$artifacts = $Env:BUILD_ARTIFACTSTAGINGDIRECTORY

foreach($inputFile in $inputFiles) {
    $fileName = "$sourceRoot\$inputFile"

    if((Test-Path($fileName)) -eq $false) {
        Write-Host "File $fileName not found, trying artifacts folder"
        $fileName = "$artifacts\$inputFile"
    }

    Push-File $sessionId $fileName
}

$code = Load-FileContent($scriptPath)
Write-Host "Session $sessionId run: $code"

$result = $ml.RemoteExecute($sessionId, $code)	
Write-Host $result

foreach($outputFile in $outputFiles) {
    Pull-File $sessionId $outputFile "$artifacts\$outputFile"
}

Write-Host "Closing session $sessionId"
$ml.CloseSession($sessionId)