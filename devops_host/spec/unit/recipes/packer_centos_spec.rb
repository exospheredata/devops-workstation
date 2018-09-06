#
# Cookbook:: devops_host
# Spec:: packer_centos_spec
#
# maintainer:: Exosphere Data, LLC
# maintainer_email:: chef@exospheredata.com
#
# Copyright:: 2018, Exosphere Data, LLC, All Rights Reserved.

require 'spec_helper'

describe 'devops_host::packer_centos' do
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
          end
        end
      end
    end
  end
end
