Param(
  [Parameter(Mandatory=$true,HelpMessage="Please enter the DataStore to which the ISO will be loaded.", Position=1)]
  [string]$DataStore
  [Parameter(Mandatory=$true,HelpMessage="Please enter the Vcenter Server to which the ISO will be loaded.", Position=2)]
  [string]$Vcenter
 )

function github_downloader {
  Param(
  [string]$Source,
  [string]$SourceChecksum,
  [string]$DestinationFolder
   )

  $ShouldDownload = $True
  $DestinationFileName = $Source.split('/')[-1]
  $DestinationPath = ($DestinationFolder + "\" + $DestinationFileName)

  New-Item -Type Directory -Path $DestinationFolder -ErrorAction SilentlyContinue

  if (!(Test-Path ($DestinationPath + ".checked"))) {

    if(Test-Path $DestinationPath){
      $DownloadedHash = (Get-FileHash $DestinationPath).Hash

      $difference = @(Compare-Object -ReferenceObject $SourceChecksum -DifferenceObject $DownloadedHash -PassThru)
      if ($difference.Count -eq 0) {
        Write-Host -ForegroundColor Green "Local File exists"
        $ShouldDownload = $False
        Set-Content -Value 'valid' -Path ($DestinationPath + ".checked")
      }
    }

    if($ShouldDownload) {

      $start_time = Get-Date
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

      $wc = New-Object System.Net.WebClient
      $wc.DownloadFile($Source, $DestinationPath)

      Write-Output "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"

      $DownloadedHash = (Get-FileHash $DestinationPath).Hash

      $difference = @(Compare-Object -ReferenceObject $SourceChecksum -DifferenceObject $DownloadedHash -PassThru)
      if ($difference.Count -eq 0) {
        Write-Host -ForegroundColor Green "Content is equal"
      } else {
        Write-Host -ForegroundColor Red "Content is different. Differences:"
        $difference
      }
    }
  }

}

function iso_downloader {
  # ISO Downloader
  Param(
    [string]$Source,
    [string]$SourceChecksum,
    [string]$DestinationFolder,
    [string]$RemoteDatastore
   )

  $ShouldDownload = $True
  $DestinationFileName = $Source.split('/')[-1]
  $DestinationPath = ($DestinationFolder + "\" + $DestinationFileName)

  New-Item -Type Directory -Path $DestinationFolder -ErrorAction SilentlyContinue

  if (!(Test-Path ($DestinationPath + ".checked"))) {

    if(Test-Path $DestinationPath){
      $DownloadedHash = (Get-FileHash $DestinationPath).Hash

      $difference = @(Compare-Object -ReferenceObject $SourceChecksum -DifferenceObject $DownloadedHash -PassThru)
      if ($difference.Count -eq 0) {
        Write-Host -ForegroundColor Green "Local File exists"
        $ShouldDownload = $False
        Set-Content -Value 'valid' -Path ($DestinationPath + ".checked")
      }
    }

    if($ShouldDownload) {

      $bitsJob = Start-BitsTransfer -source $Source -destination $DestinationPath

      $DownloadedHash = (Get-FileHash $DestinationPath).Hash

      $difference = @(Compare-Object -ReferenceObject $SourceChecksum -DifferenceObject $DownloadedHash -PassThru)
      if ($difference.Count -eq 0) {
        Write-Host -ForegroundColor Green "Content is equal"
      } else {
        Write-Host -ForegroundColor Red "Content is different. Differences:"
        $difference
      }
    }
  }

  try {
    Connect-VIServer -Server $Vcenter
    $datastore = Get-Datastore $RemoteDatastore
    New-PSDrive -Location $datastore -Name exsds -PSProvider VimDatastore -Root "\" -ErrorAction SilentlyContinue
    New-Item -Path exsds:\packer_cache -ItemType Directory -ErrorAction SilentlyContinue
    Copy-DatastoreItem -Item $DestinationPath -Destination exsds:\packer_cache\$DestinationFileName
  } catch {
    throw $_.Exception.message
  } finally {
    Remove-PsDrive -Name exsds -Confirm:$False
    Disconnect-ViServer -Confirm:$False
  }

}

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$CWD = Get-Location
Set-Location $scriptPath

try {
  git submodule init

  git pull --recurse-submodules

  git config --local include.path ../.gitconfig


  $PackerPlugin = "https://github.com/jetbrains-infra/packer-builder-vsphere/releases/download/v2.0/packer-builder-vsphere-iso.exe"
  $PackerPluginChecksum = "8422f11f9a4ae46fdaefe345e8d7ed2cd9f98f724191c97650870f490f722602"
  $PackerPluginDirectory = "$env:APPDATA\\packer.d\\plugins\\"

  github_downloader -Source $PackerPlugin -SourceChecksum $PackerPluginChecksum -DestinationFolder $PackerPluginDirectory

  $CentosISO      = "https://mirrors.edge.kernel.org/centos/7/isos/x86_64/CentOS-7-x86_64-Minimal-1804.iso"
  $CentosChecksum = "714acc0aefb32b7d51b515e25546835e55a90da9fb00417fbee2d03a62801efd"
  $LocalCache     = $($PWD.Path+"\packer_cache")

  iso_downloader -Source $CentosISO -SourceChecksum $CentosChecksum -DestinationFolder $LocalCache -RemoteDatastore $DataStore


  $EVAL_WIN2016_X64 = "https://software-download.microsoft.com/download/pr/Windows_Server_2016_Datacenter_EVAL_en-us_14393_refresh.ISO"
  $EVAL_WIN2016_X64_CHECKSUM = "1CE702A578A3CB1AC3D14873980838590F06D5B7101C5DAACCBAC9D73F1FB50F"
  $LocalCache     = $($PWD.Path+"\packer_cache")
  iso_downloader -Source $EVAL_WIN2016_X64 -SourceChecksum $EVAL_WIN2016_X64_CHECKSUM -DestinationFolder $LocalCache -RemoteDatastore $DataStore

} catch {
  throw $_.Exception.message
} finally {
  Set-Location $CWD
}
