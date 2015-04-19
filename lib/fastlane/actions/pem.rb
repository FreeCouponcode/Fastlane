module Fastlane
  module Actions
    module SharedValues
      
    end

    class PemAction < Action
      def self.run(params)
        require 'pem'
        require 'pem/options'
        require 'pem/manager'

        values = params.first

        begin
          FastlaneCore::UpdateChecker.start_looking_for_update('pem') unless Helper.is_test?

          success_block = values[:new_profile]
          values.delete(:new_profile) # as it's not in the configs

          PEM.config = FastlaneCore::Configuration.create(PEM::Options.available_options, (values || {}))
          profile_path = PEM::Manager.start

          if profile_path
            success_block.call(File.expand_path(profile_path))
          end
        ensure
          FastlaneCore::UpdateChecker.show_update_status('pem', PEM::VERSION)
        end
      rescue => ex
        puts ex
      end

      def self.description
        "Makes sure a valid push profile is active and creates a new one if needed"
      end

      def self.details
        [
          "Additionally to the available options, you can also specify a block that only gets executed if a new",
          "profile was created. You can use it to upload the new profile to your server.",
          "Use it like this: ",
          "pem(",
          "  new_profile: Proc.new do ",
          "    # your upload code",
          "  end",
          ")"
        ].join("\n")
      end

      def self.available_options
        require 'pem'
        require 'pem/options'
        PEM::Options.available_options
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
