#
# Cookbook:: devops_host
# Recipe:: host_config
#
# maintainer:: Exosphere Data, LLC
# maintainer_email:: chef@exospheredata.com
#
# Copyright:: 2018, Exosphere Data, LLC, All Rights Reserved.

%w(terraform chefdk sublimetext3 putty packer winscp conemu poshgit).each do |pkg|
  chocolatey_package "Install Package: #{pkg}" do
    package_name pkg
    action :install
  end
end

# Make sure subl.exe is available in our path
windows_path 'C:\\Program Files\\Sublime Text 3' do
  action :add
end

# We want to get our host up to PowerShell v5 for the other components
# This will require a reboot.  Using the notifies allows us to only prompt
# for a reboot when something changes.
chocolatey_package 'powershell' do
  provider Chef::Provider::Package::Chocolatey
  returns [0, 3010]
  action :install
  notifies :reboot_now, 'reboot[Restart Computer]', :immediately
end

reboot 'Restart Computer' do
  action :nothing
end

powershell_script 'Install NuGet' do
  code <<-EOH
  Install-PackageProvider -Name Nuget -MinimumVersion 2.8.5.201 -Force
  EOH
  guard_interpreter :powershell_script
  not_if '[boolean](Get-PackageProvider | ?{$_.Name -eq "NuGet"})'
end

# If the Hyper-V modules are installed, then we need to remove them completely before we try
# to install PowerCLI as of version 10.0.0 due to changes in how the PowerCLI installation
# works.  Due to limitations, we will simply rename the directory.
powershell_script 'Rename Hyper-V module' do
  code <<-EOH
  Remove-Module Hyper-V
  Rename-Item 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\Modules\\Hyper-V' 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\Modules\\OldHyperV'
  EOH
  action :run
  guard_interpreter :powershell_script
  only_if '[boolean](Test-Path -Path "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\Modules\\Hyper-V\")'
end

package 'VMware vSphere PowerCLI' do
  action :remove
end

# Install the PowerCLI module if not installed
powershell_script 'Install VMWare PowerCli' do
  code <<-EOH
  Find-Module VMware.PowerCLI
  Install-Module -Name VMware.PowerCLI -Force
  EOH
  guard_interpreter :powershell_script
  not_if '[boolean](Get-Module -ListAvailable -Name "VMware.PowerCLI")'
  action :run
end

powershell_script 'Ignore vCenter SSL Warnings' do
  code <<-EOH
  Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -InvalidCertificateAction ignore -Confirm:$False | Out-Null
  EOH
  guard_interpreter :powershell_script
  action :run
end
