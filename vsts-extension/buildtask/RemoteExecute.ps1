Trace-VstsEnteringInvocation $MyInvocation

$scriptRuntime = Get-VstsInput -Name ScriptRuntime
$scriptPath = Get-VstsInput -Name ScriptPath
$inputFiles = Get-VstsInput -Name InputFiles
$outputFiles = Get-VstsInput -Name OutputFiles

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

$rSession = $ml.CreateSession($scriptRuntime)

function Push-File([string]$session, [string]$fileName)
{
    $fileStream = [System.IO.File]::OpenRead($fileName)
	$ml.PushFile($session, $fileStream)
	$fileStream.Close()
}

function Pull-File([string]$session, [string]$fileName, [string]$destinationPath)
{
    $fileStream = $ml.PullFile($session, $fileName)
    $outputStream = [System.IO.File]::OpenWrite($destinationPath)
    $fileStream.CopyTo($outputStream)
    $fileStream.Close()
    $outputStream.Close()
}

function Run-Code([string]$session, [string]$code)
{
    $result = $ml.RemoteExecute($session, $code)	
    Write-Host $result
}

function Load-SourceFiles([string]$session, $fileName)
{
    $reader = [System.IO.File]::OpenText($fileName)
    $content = $reader.ReadToEnd()
    $result = $ml.RemoteExecute($session, $content)	
    Write-Host $result
    $reader.Close()
}

foreach($inputFile in $inputFiles) {
    Write-Host $inputFile
}

$result = Load-SourceFiles($rSession, $scriptPath)
Write-Host $result

foreach($outputFile in $outputFiles) {
    Write-Host $outputFile
}

$ml.CloseSession($rSession)