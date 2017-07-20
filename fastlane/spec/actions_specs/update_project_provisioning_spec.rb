describe Fastlane do
  describe Fastlane::FastFile do
    describe "Update Project Provisioning" do
      let (:fixtures_path) { "./fastlane/spec/fixtures" }
      let (:xcodeproj) { File.absolute_path(File.join(fixtures_path, 'xcodeproj', 'bundle.xcodeproj')) }
      let (:profile_path) { File.absolute_path(File.join(fixtures_path, 'profiles', 'test.mobileprovision')) }
      describe "target_filter" do
        before do
          allow(Fastlane::Actions::UpdateProjectProvisioningAction).to receive(:run)
        end

        context 'with String' do
          it 'should be valid' do
            expect {
              Fastlane::FastFile.new.parse("lane :test do
                  update_project_provisioning ({
                    xcodeproj: '#{xcodeproj}',
                    profile: '#{profile_path}',
                    target_filter: 'Name'
                })
              end").runner.execute(:test)
            }.not_to raise_error
          end
        end

        context 'with Regexp' do
          it 'should be valid' do
            expect {
              Fastlane::FastFile.new.parse("lane :test do
                  update_project_provisioning ({
                    xcodeproj: '#{xcodeproj}',
                    profile: '#{profile_path}',
                    target_filter: /Name/
                })
              end").runner.execute(:test)
            }.not_to raise_error
          end
        end

        context 'with other type' do
          it 'should be invalid' do
            expect {
              Fastlane::FastFile.new.parse("lane :test do
                  update_project_provisioning ({
                    xcodeproj: '#{xcodeproj}',
                    profile: '#{profile_path}',
                    target_filter: 1
                })
              end").runner.execute(:test)
            }.to raise_error
          end
        end
      end
    end
  end
end
