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
          end.to raise_error("`apple_id` value is incorrect. App ID consists of a Team ID and a bundle ID search string, with a period (.) separating the two parts. You can find your Team ID here: https://developer.apple.com/account/#/membership and your bundle ID in Xcode settings.")
        end

        it "raises an error if `apple_id` contains team id with invalid characters" do
          expect do
            options = {
              username: "username@example.com",
              apple_id: "A!C@0ABC1.com.bundle.identifier"
            }
            pilot_config = FastlaneCore::Configuration.create(Pilot::Options.available_options, options)
          end.to raise_error("`apple_id` value is incorrect. App ID consists of a Team ID and a bundle ID search string, with a period (.) separating the two parts. You can find your Team ID here: https://developer.apple.com/account/#/membership and your bundle ID in Xcode settings.")
        end

        it "raises an error if `apple_id` contains team id with invalid characters count" do
          expect do
            options = {
              username: "username@example.com",
              apple_id: "ABC101.com.bundle.identifier"
            }
            pilot_config = FastlaneCore::Configuration.create(Pilot::Options.available_options, options)
          end.to raise_error("`apple_id` value is incorrect. App ID consists of a Team ID and a bundle ID search string, with a period (.) separating the two parts. You can find your Team ID here: https://developer.apple.com/account/#/membership and your bundle ID in Xcode settings.")
        end

        it "raises an error if `apple_id` contains only team id" do
          expect do
            options = {
              username: "username@example.com",
              apple_id: "ABC101ABC1"
            }
            pilot_config = FastlaneCore::Configuration.create(Pilot::Options.available_options, options)
          end.to raise_error("`apple_id` value is incorrect. App ID consists of a Team ID and a bundle ID search string, with a period (.) separating the two parts. You can find your Team ID here: https://developer.apple.com/account/#/membership and your bundle ID in Xcode settings.")
        end

        it "raises an error if `apple_id` contains correct team id and bundle id with invalid characters" do
          expect do
            options = {
              username: "username@example.com",
              apple_id: "ABC1234567.com.bundle.id@ent!fier?"
            }
            pilot_config = FastlaneCore::Configuration.create(Pilot::Options.available_options, options)
          end.to raise_error("`apple_id` value is incorrect. App ID consists of a Team ID and a bundle ID search string, with a period (.) separating the two parts. You can find your Team ID here: https://developer.apple.com/account/#/membership and your bundle ID in Xcode settings.")
        end

        it "passes when `apple_id` is correct" do
          options = {
            username: "username@example.com",
            apple_id: "ABCD9089AC.com.bundle.identifier"
          }
          pilot_config = FastlaneCore::Configuration.create(Pilot::Options.available_options, options)
          expect(pilot_config[:apple_id]).to eq('ABCD9089AC.com.bundle.identifier')
        end
      end
    end
  end
end
