describe Fastlane do
  describe Fastlane::FastFile do
    describe "pilot Integration" do
      it "can use a generated changelog as release notes" do
        values = Fastlane::FastFile.new.parse("lane :test do
          # changelog_from_git_commits sets this lane context variable
          Actions.lane_context[SharedValues::FL_CHANGELOG] = 'autogenerated changelog'
          pilot
        end").runner.execute(:test)

        expect(values[:changelog]).to eq('autogenerated changelog')
      end

      it "prefers an explicitly specified changelog value" do
        values = Fastlane::FastFile.new.parse("lane :test do
          # changelog_from_git_commits sets this lane context variable
          Actions.lane_context[SharedValues::FL_CHANGELOG] = 'autogenerated changelog'
          pilot(changelog: 'custom changelog')
        end").runner.execute(:test)

        expect(values[:changelog]).to eq('custom changelog')
      end

      describe "Test `apple_id` parameter" do
        it "raises an error if `apple_id` is set to email address" do
          expect do
            options = {
              username: "username@example.com",
              apple_id: "username@example.com"
            }
            pilot_config = FastlaneCore::Configuration.create(Pilot::Options.available_options, options)
          end.to raise_error("`apple_id` value is incorrect. The correct value should be taken from Apple ID property in the App Information section in App Store Connect.")
        end

        it "raises an error if `apple_id` is set to bundle identifier" do
          expect do
            options = {
              username: "username@example.com",
              apple_id: "com.bundle.identifier"
            }
            pilot_config = FastlaneCore::Configuration.create(Pilot::Options.available_options, options)
          end.to raise_error("`apple_id` value is incorrect. The correct value should be taken from Apple ID property in the App Information section in App Store Connect.")
        end

        it "passes when `apple_id` is correct" do
          options = {
            username: "username@example.com",
            apple_id: "123456789"
          }
          pilot_config = FastlaneCore::Configuration.create(Pilot::Options.available_options, options)
          expect(pilot_config[:apple_id]).to eq('123456789')
        end
      end
    end
  end
end
