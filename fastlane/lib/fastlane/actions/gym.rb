module Fastlane
  module Actions
    require_relative 'build_ios_app'
    class GymAction < BuildIosAppAction
      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Alias for the `build_ios_app` action"
      end
    end
  end
end
