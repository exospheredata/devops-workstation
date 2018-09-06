#
# Cookbook:: devops_host
# Spec:: default_spec
#
# maintainer:: Exosphere Data, LLC
# maintainer_email:: chef@exospheredata.com
#
# Copyright:: 2017, Exosphere Data, LLC, All Rights Reserved.

require 'spec_helper'

describe 'devops_host::default' do
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

          let(:chef_run) { ChefSpec::SoloRunner.new(platform: platform, version: version).converge(described_recipe) }

          it 'converges successfully' do
            expect { chef_run }.to_not raise_error
            expect(chef_run).to include_recipe('devops_host::host_config')
            expect(chef_run).to include_recipe('devops_host::configure_vmware')
          end
        end
      end
    end
  end
end
