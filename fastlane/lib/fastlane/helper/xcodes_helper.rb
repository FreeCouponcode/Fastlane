module Fastlane
  module Helper
    class XcodesHelper
      def self.read_xcode_version_file
        xcode_version_paths = Dir.glob(".xcode-version")

        if xcode_version_paths.first
          return File.read(xcode_version_paths.first).strip
        end

        return nil
      end

      def self.find_xcodes_binary_path
        Actions.sh("which xcodes", log: false).strip
      end

      module Verify
        def self.requirement(req)
          UI.user_error!("Version must be specified") if req.nil? || req.to_s.strip.size == 0
          Gem::Requirement.new(req.to_s)
        rescue Gem::Requirement::BadRequirementError
          UI.user_error!("The requirement '#{req}' is not a valid RubyGems style requirement")
        end
      end
    end
  end
end
