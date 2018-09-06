#
# Cookbook:: devops_host
# Spec:: host_config_spec
#
# maintainer:: Exosphere Data, LLC
# maintainer_email:: chef@exospheredata.com
#
# Copyright:: 2018, Exosphere Data, LLC, All Rights Reserved.

require 'spec_helper'

describe 'devops_host::host_config' do
  before do
    stub_command("[boolean](Get-PackageProvider | ?{$_.Name -eq \"NuGet\"})").and_return(false)
    stub_command("[boolean](Get-Module -ListAvailable -Name \"VMware.PowerCLI\")").and_return(false)
    stub_command("[boolean](Test-Path -Path \"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\Modules\\Hyper-V\\\")").and_return(true)
  end
  context 'Install prequisite components' do
    platforms = {
      'windows' => {
        'versions' => %w(2012r2 2016)
      }
    }

    platforms.each do |platform, components|
      components['versions'].each do |version|
        context "On #{platform} #{version}" do
          before do
            Fauxhai.mock(platform: platform, version: version)
          end

          let(:runner) do
            ChefSpec::SoloRunner.new(platform: platform, version: version, file_cache_path: '/tmp/cache')
          end
          let(:node) { runner.node }
          let(:chef_run) { runner.converge(described_recipe) }

          it 'converges successfully' do
            expect { chef_run }.to_not raise_error
            %w(terraform chefdk sublimetext3 putty packer winscp).each do |pkg|
              expect(chef_run).to install_chocolatey_package("Install Package: #{pkg}")
            end
            expect(chef_run).to add_windows_path('C:\\Program Files\\Sublime Text 3')
            expect(chef_run).to install_chocolatey_package('powershell')
            expect(chef_run).to run_powershell_script('Install NuGet')
            expect(chef_run).to run_powershell_script('Rename Hyper-V module')
            expect(chef_run).to remove_package('VMware vSphere PowerCLI')
            expect(chef_run).to run_powershell_script('Install VMWare PowerCli')
            expect(chef_run).to run_powershell_script('Ignore vCenter SSL Warnings')

            reboot_resource = chef_run.reboot('Restart Computer')
            expect(reboot_resource).to do_nothing

            powershell = chef_run.chocolatey_package('powershell')
            expect(powershell).to notify('reboot[Restart Computer]').to(:reboot_now).immediately
          end
        end
      end
    end
  end
end
