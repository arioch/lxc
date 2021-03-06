################################################################################
#
#      Author: Zachary Patten <zachary AT jovelabs DOT com>
#   Copyright: Copyright (c) Zachary Patten
#     License: Apache License, Version 2.0
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
################################################################################
require "spec_helper"

describe LXC do

  subject { LXC.new }

  describe "class" do

    it "should be an instance of LXC" do
      subject.should be_an_instance_of LXC
    end

  end

  describe "methods" do

    LXC_VERSIONS.each do |lxc_version|
      context "LXC Target Version #{lxc_version}" do

        describe "#config" do

          it "should return us an instance of the LXC::Config class representing the main LXC configuration file" do
            subject.config.should be_kind_of(LXC::Config)
            subject.config.filename.should == "/etc/lxc/lxc.conf"
          end

        end

        describe "#ls" do

          context "with containers" do

            it "should return an array of strings populated with container names" do
              subject.stub(:exec) { lxc_fixture(lxc_version, "lxc-ls-w-containers.out") }

              subject.ls.should be_kind_of(Array)
              subject.ls.should_not be_empty
              subject.ls.size.should eq(2)
            end

          end

          context "without containers" do

            it "should return an empty array" do
              subject.stub(:exec) { lxc_fixture(lxc_version, "lxc-ls-wo-containers.out") }

              subject.ls.should be_kind_of(Array)
              subject.ls.should be_empty
              subject.ls.size.should eq(0)
            end

          end

        end

        describe "#exists?" do

          context "with containers" do

            it "should return false if the container does not exist" do
              subject.stub(:exec) { lxc_fixture(lxc_version, "lxc-ls-w-containers.out") }
              subject.exists?("abc-123-test-container-name").should == false
            end

            it "should return true if the container does exist" do
              subject.stub(:exec) { lxc_fixture(lxc_version, "lxc-ls-w-containers.out") }
              subject.exists?("devop-test-1").should == true
            end

          end

          context "without containers" do

            it "should return false if the container does not exist" do
              subject.stub(:exec) { lxc_fixture(lxc_version, "lxc-ls-wo-containers.out") }
              subject.exists?("abc-123-test-container-name").should == false
            end

            it "should return false if the container does not exist" do
              subject.stub(:exec) { lxc_fixture(lxc_version, "lxc-ls-wo-containers.out") }
              subject.exists?("devop-test-1").should == false
            end

          end

        end

        describe "#ps" do
          it "should return an array of strings representing the lxc process list" do
            subject.stub(:exec) { lxc_fixture(lxc_version, "lxc-ps.out") }

            subject.ps.should be_kind_of(Array)
            subject.ps.should_not be_empty
          end
        end

        describe "#version" do
          it "should return a string representation of the installed LXC version" do
            subject.stub(:exec) { lxc_fixture(lxc_version, 'lxc-version.out') }

            subject.version.should be_kind_of(String)
            subject.version.should_not be_empty
            subject.version.should == lxc_version
          end
        end

        describe "#checkconfig" do
          it "should return an array of strings representing the LXC configuration" do
            subject.stub(:exec) { lxc_fixture(lxc_version, 'lxc-checkconfig.out') }

            subject.checkconfig.should be_kind_of(Array)
            subject.checkconfig.should_not be_empty

            subject.checkconfig.first.should be_kind_of(String)
            subject.checkconfig.first.should_not be_empty
          end
        end

        describe "#container" do
          it "should return a container object for the requested container" do
            result = subject.container("devop-test-1")
            result.should be_an_instance_of(::LXC::Container)
          end
        end

        describe "#containers" do

          context "with containers" do
            it "should return an array of container objects" do
              subject.stub(:exec) { lxc_fixture(lxc_version, "lxc-ls-w-containers.out") }

              subject.containers.should be_kind_of(Array)
              subject.containers.size.should eq(2)
            end
          end

          context "without containers" do
            it "should return an empty array" do
              subject.stub(:exec) { lxc_fixture(lxc_version, "lxc-ls-wo-containers.out") }

              subject.containers.should be_kind_of(Array)
              subject.containers.size.should eq(0)
            end
          end

        end

        describe "#inspect" do
          it "should return an information string about our class instance" do
            subject.stub(:exec) { lxc_fixture(lxc_version, "lxc-version.out") }

            subject.inspect.should be_kind_of(String)
            subject.inspect.length.should be > 0
          end
        end

        describe "#exec" do

          context "against local host" do
            it "should exec the supplied LXC command" do
              subject.stub(:exec) { lxc_fixture(lxc_version, "lxc-version.out") }

              subject.exec("lxc-version").should be_kind_of(String)
            end
          end

          context "against remote host" do

            subject {
              connection = ::ZTK::SSH.new(
                :host_name => "127.0.0.1",
                :user => ENV['USER'],
                :keys => File.join(ENV['HOME'], '.ssh', 'id_rsa'),
                :keys_only => true
              )
              runner = ::LXC::Runner::SSH.new(:ssh => connection)

              LXC.new(:runner => runner)
            }

            it "should exec the supplied LXC command" do
              subject.exec("version").should be_kind_of(String)
            end
          end if !ENV['CI'] && !ENV['TRAVIS']

        end

      end # LXC Version Context
    end # LXC_VERSIONS

  end

end
