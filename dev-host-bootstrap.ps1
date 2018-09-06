param(
  $git_key = ''
  )
$_scriptName = (Split-Path $MyInvocation.MyCommand.Path -Leaf)
$_scriptPath = (Split-Path $MyInvocation.MyCommand.Path -Parent)
$_Location = $cwd

# If the current Get-ExecutionPolicy returns as Restricted, then we must
# enable bypassing this for the purposes of this script.
if ( (Get-ExecutionPolicy) -eq "Restricted") {
  $CurrentExecutionPolicy = Get-ExecutionPolicy
  Set-ExecutionPolicy Bypass
}

# Install Chocolatey Package manager for Windows.
if ( ! [boolean] ( Get-Command -Name choco -ErrorAction SilentlyContinue )){
  Write-Host "LOG: This must be the first execution because we didn't find chocolatey.  Time to install."
  iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
  $_refreshVars = $True
}

# Now that we have Chocolatey installed, we can begin installing all of the developer tools
# that we need on the host.  To do this, we will first install Git and Chef-Client.  Once these
# tools are installed, we can perform a self-configuration bootstrap

# Install Git
if ( ! [boolean] ( Get-Command -Name git -ErrorAction SilentlyContinue )){
  Write-Host "LOG: We will now install Git tools on this host."
  choco install git -y | Out-Null
  $_refreshVars = $True
}

# Install Chef-Client
if ( ! [boolean] ( Get-Command -Name 'chef-solo' -ErrorAction SilentlyContinue )){
  Write-Host "LOG: We will now install ChefDK on this host."
  choco install chefdk -y | Out-Null
  $_refreshVars = $True
}

# We need to force the reloading of all environment variables now that we installed these new tools.
if ( $_refreshVars ){
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

# Now that we have the initial tools, we can clone the DevHost cookbook configuration locally.
if ( ! (Test-Path -Path $_scriptPath\devops-workstation) ) {
  Write-Host "LOG: This might the first time that you are running this or you have decided to start over.  In the meantime, we need to clone the DevOps Demo repository."
  if ( $git_key ){ $git_key = $git_key + '@' }
  $_cloneRepoUrl = "https://" + $git_key + "github.com/exospheredata/devops-workstation.git"
  try {
    # Git reports to Stderr even on success so we will mute and if the second test fails then we will replay and throw the error.
    Invoke-Command -ScriptBlock { git clone $_cloneRepoUrl $_scriptPath\devops-workstation 2>$null}
    Invoke-Command -ScriptBlock { $here = Get-Location; cd $_scriptPath\devops-workstation; git checkout feature/dev_host_config 2>$null; cd $here}
    if ( ! (Test-Path -Path $_scriptPath\devops-workstation) ) {
      Invoke-Command -ScriptBlock { git clone $_cloneRepoUrl $_scriptPath\devops-workstation}
      Remove-Item -Force -Recurse $_scriptPath\devops-workstation -ErrorAction SilentlyContinue
    }
  }
  catch {
    throw $_.Exception.message
  }

} else {
  try {
    Invoke-Command -ScriptBlock { $here = Get-Location; cd $_scriptPath\devops-workstation; git pull 2>$null; cd $here}

  }
  catch {
    throw $_.Exception.message
  }
}

New-Item -Type Directory -Path $_scriptPath\tmp -ErrorAction SilentlyContinue | Out-Null

$_soloContent = @"
root = $("'" + $_scriptPath.replace("\","/") + "'")
file_cache_path root
cookbook_path root + '/devops-workstation'
data_bag_path root + '/data_bags'
"@
$_soloRB = $($_scriptPath + "\tmp\devops_host_solo.json")
[IO.File]::WriteAllLines($_soloRB, $_soloContent)

$_attributes = @{}
$_attributes['run_list'] = @('devops_host::default')
$_dnaJson = $($_scriptPath + "\tmp\devops_host_dna.json")
[IO.File]::WriteAllLines($_dnaJson, $($_attributes | ConvertTo-Json -Depth 10))

Invoke-Command -ScriptBlock {chef-solo -c $_soloRB -j $_dnaJson  -l info }
