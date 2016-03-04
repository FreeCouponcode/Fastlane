module Fastlane
  module Actions
    module SharedValues
      BUILD_SETTING_FOR_BUILD_NUMBER = :BUILD_SETTING_FOR_BUILD_NUMBER
    end

    class SetBuildNumberRepositoryAction < Action
      def self.is_supported?(platform)
        [:ios, :mac].include? platform
      end

      def self.run(params)
        build_number = Fastlane::Actions::GetBuildNumberRepositoryAction.run(
          use_hg_revision_number: params[:use_hg_revision_number]
        )

        if params[:build_number_as_build_setting]
          # This will pass the build number as the build setting specified to xcodebuild and gym.
          # This will only modify the plist files if they haven't been set to this value before.
          build_setting = params[:build_number_as_build_setting]
          Fastlane::Actions::IncrementBuildNumberAction.run(build_number: "'\\$(#{build_setting})'")
          Actions.lane_context[SharedValues::BUILD_SETTING_FOR_BUILD_NUMBER] = build_setting
          Actions.lane_context[SharedValues::BUILD_NUMBER] = build_number.chomp
        else
          Fastlane::Actions::IncrementBuildNumberAction.run(build_number: build_number)
        end
      end

      def self.add_build_number_build_setting(dictionary, key)
        build_setting_for_build_number = Actions.lane_context[SharedValues::BUILD_SETTING_FOR_BUILD_NUMBER]
        if build_setting_for_build_number
          build_number = Actions.lane_context[SharedValues::BUILD_NUMBER]
          dictionary[key] ||= ""
          dictionary[key] += " #{build_setting_for_build_number}=#{build_number}"
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Set the build number from the current repository"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :build_number_as_build_setting,
                                       env_name: "BUILD_NUMBER_AS_BUILD_SETTING",
                                       description: "Pass the build number into the build via a build variable instead of modifying the plist files",
                                       optional: true,
                                       is_string: true,
                                       default_value: nil),

          FastlaneCore::ConfigItem.new(key: :use_hg_revision_number,
                                       env_name: "USE_HG_REVISION_NUMBER",
                                       description: "Use hg revision number instead of hash (ignored for non-hg repos)",
                                       optional: true,
                                       is_string: false,
                                       default_value: false)
        ]
      end

      def self.output
        [
        ]
      end

      def self.authors
        ["pbrooks", "armadsen"]
      end
    end
  end
end
