module Fastlane
  module Actions
    class GitHasChangesAction < Action
      def self.run(params)
        if params[:path].kind_of?(String)
          paths = params[:path].shellescape
        else
          paths = params[:path].map(&:shellescape).join(' ')
        end

        result = Actions.sh("git status --porcelain #{paths}")
        UI.success("git status \"#{params[:path]}\" 💾.")
        return result
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Show the status of a given file or directory"
      end

      def self.details
        ""
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :path,
                                       description: "The file or directory you want to see the status",
                                       is_string: false,
                                       verify_block: proc do |value|
                                         if value.kind_of?(String)
                                           UI.user_error!("Couldn't find file at path '#{value}'") unless File.exist?(value)
                                         else
                                           value.each do |x|
                                             UI.user_error!("Couldn't find file at path '#{x}'") unless File.exist?(x)
                                           end
                                         end
                                       end)
        ]
      end

      def self.output
      end

      def self.return_value
        nil
      end

      def self.authors
        ["4brunu"]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
