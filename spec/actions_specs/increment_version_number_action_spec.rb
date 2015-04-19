describe Fastlane do
  describe Fastlane::FastFile do
    describe "Increment Version Number Integration" do
      require 'shellwords'

      it "it increments all targets patch version number" do
        Fastlane::FastFile.new.parse("lane :test do
          increment_version_number
        end").runner.execute(:test)

        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::VERSION_NUMBER]).to match(/cd .* && agvtool new-marketing-version 1.0.1/)
      end

      it "it increments all targets minor version number" do
        Fastlane::FastFile.new.parse("lane :test do
          increment_version_number(bump_type: 'minor')
        end").runner.execute(:test)

        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::VERSION_NUMBER]).to match(/cd .* && agvtool new-marketing-version 1.1.0/)
      end

      it "it increments all targets minor version major" do
        Fastlane::FastFile.new.parse("lane :test do
          increment_version_number(bump_type: 'major')
        end").runner.execute(:test)

        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::VERSION_NUMBER]).to match(/cd .* && agvtool new-marketing-version 2.0.0/)
      end

      it "pass a custom version number" do
        result = Fastlane::FastFile.new.parse("lane :test do
          increment_version_number(version_number: '1.4.3')
        end").runner.execute(:test)

        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::VERSION_NUMBER]).to match(/cd .* && agvtool new-marketing-version 1.4.3/)
      end

      it "raises an exception when xcode project path wasn't found" do
        expect {
          Fastlane::FastFile.new.parse("lane :test do
            increment_version_number(xcodeproj: '/nothere')
          end").runner.execute(:test)
        }.to raise_error("Could not find Xcode project".red)
      end

      it "raises an exception when use passes workspace" do
        expect {
          Fastlane::FastFile.new.parse("lane :test do
            increment_version_number(xcodeproj: 'project.xcworkspace')
          end").runner.execute(:test)
        }.to raise_error("Please pass the path to the project, not the workspace".red)
      end

      it "raises an exception if given version number is invalid" do
        expect {
          Fastlane::FastFile.new.parse("lane :test do
            increment_version_number(version_number: '3')
          end").runner.execute(:test)
        }.to raise_error("Invalid version '3' given. Must be x.y.z".red)
      end
    end
  end
end
