#
# Cookbook:: devops_host
# Spec:: configure_vmware_spec
#
# maintainer:: Exosphere Data, LLC
# maintainer_email:: chef@exospheredata.com
#
# Copyright:: 2018, Exosphere Data, LLC, All Rights Reserved.

require 'spec_helper'

describe 'devops_host::configure_vmware' do
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

          let(:chef_run) { ChefSpec::SoloRunner.new(platform: platform, version: version, file_cache_path: '/tmp/cache').converge(described_recipe) }

          it 'converges successfully' do
            expect { chef_run }.to_not raise_error
            expect(chef_run).to run_powershell_script('Configure SSH on ESX hosts')
            expect(chef_run).to run_powershell_script('Enable VNC for the ESX Host')
            expect(chef_run).to run_powershell_script('Clean up the hosts of all Virtual Machines')
            expect(chef_run).to run_powershell_script('Create vCenter Templates Folder')

            notification = chef_run.powershell_script('Clean up the hosts of all Virtual Machines')
            expect(notification).to notify("file[#{Chef::Config[:file_cache_path]}\\.vmware-vms.deleted]").to(:create).immediately

            vm_clean = chef_run.file("#{Chef::Config[:file_cache_path]}\\.vmware-vms.deleted")
            expect(vm_clean).to do_nothing
          end
        end
      end
    end
  end
end
