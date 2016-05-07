module Fastlane
  module Actions
    module SharedValues
      FL_CHANGELOG = :FL_CHANGELOG
    end

    class ChangelogFromGitCommitsAction < Action
      def self.run(params)
        if params[:between] and params[:commits_count]
          UI.user_error!(":commits_count and :between must not be used at the same time")
        end

        if params[:commits_count]
          UI.success("Collecting #{params[:commits_count]} last Git commits")
        else
          if params[:between]
            from, to = params[:between]
          else
            from = Actions.last_git_tag_name(params[:match_lightweight_tag], params[:tag_match_pattern])
            UI.verbose("Found the last Git tag: #{from}")
            to = 'HEAD'
          end
          UI.success("Collecting Git commits between #{from} and #{to}")
        end



        # Normally it is not good practice to take arbitrary input and convert it to a symbol
        # because prior to Ruby 2.2, symbols are never garbage collected. However, we've
        # already validated that the input matches one of our allowed values, so this is OK
        merge_commit_filtering = params[:merge_commit_filtering].to_sym

        # We want to be specific and exclude nil for this comparison
        if params[:include_merges] == false
          merge_commit_filtering = :exclude_merges
        end

        if params[:commits_count]
          changelog = Actions.git_log_last_commits(params[:pretty], params[:commits_count], merge_commit_filtering)
        else
          changelog = Actions.git_log_between(params[:pretty], from, to, merge_commit_filtering)
        end
        changelog = changelog.gsub("\n\n", "\n") if changelog # as there are duplicate newlines
        Actions.lane_context[SharedValues::FL_CHANGELOG] = changelog

        changelog
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Collect git commit messages into a changelog"
      end

      def self.details
        "By default, messages will be collected back to the last tag, but the range can be controlled"
      end

      def self.output
        ['FL_CHANGELOG', 'The changelog String generated from the collected Git commit messages']
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :between,
                                       env_name: 'FL_CHANGELOG_FROM_GIT_COMMITS_BETWEEN',
                                       description: 'Array containing two Git revision values between which to collect messages, you mustn\'t use it with :commits_count key at the same time',
                                       optional: true,
                                       is_string: false,
                                       verify_block: proc do |value|
                                         UI.user_error!(":between must be of type array") unless value.kind_of?(Array)
                                         UI.user_error!(":between must not contain nil values") if value.any?(&:nil?)
                                         UI.user_error!(":between must be an array of size 2") unless (value || []).size == 2
                                       end),
         FastlaneCore::ConfigItem.new(key: :commits_count,
                                      env_name: 'FL_CHANGELOG_FROM_GIT_COMMITS_COUNT',
                                      description: 'Number of commits to include in changelog, you mustn\'t use it with :between key at the same time',
                                      optional: true,
                                      is_string: false,
                                      verify_block: proc do |value|
                                        UI.user_error!(":commits_count must be an integer") unless value.is_a? Integer
                                        UI.user_error!(":commits_count must be >= 1") unless value >= 1
                                      end),
          FastlaneCore::ConfigItem.new(key: :pretty,
                                       env_name: 'FL_CHANGELOG_FROM_GIT_COMMITS_PRETTY',
                                       description: 'The format applied to each commit while generating the collected value',
                                       optional: true,
                                       default_value: '%B',
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :tag_match_pattern,
                                       env_name: 'FL_CHANGELOG_FROM_GIT_COMMITS_TAG_MATCH_PATTERN',
                                       description: 'A glob(7) pattern to match against when finding the last git tag',
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :match_lightweight_tag,
                                       env_name: 'FL_CHANGELOG_FROM_GIT_COMMITS_MATCH_LIGHTWEIGHT_TAG',
                                       description: 'Whether or not to match a lightweight tag when searching for the last one',
                                       optional: true,
                                       default_value: true,
                                       is_string: false),
          FastlaneCore::ConfigItem.new(key: :include_merges,
                                       env_name: 'FL_CHANGELOG_FROM_GIT_COMMITS_INCLUDE_MERGES',
                                       description: "Whether or not to include any commits that are merges\n" + '(DEPRECATED - use :merge_commit_filtering)'.red,
                                       optional: true,
                                       is_string: false,
                                       verify_block: proc do |value|
                                         UI.important "The :include_merges option is deprecated. Please use :merge_commit_filtering instead" unless value.nil?
                                       end),
          FastlaneCore::ConfigItem.new(key: :merge_commit_filtering,
                                       env_name: 'FL_CHANGELOG_FROM_GIT_COMMITS_MERGE_COMMIT_FILTERING',
                                       description: "Controls inclusion of merge commits when collecting the changelog.\nValid values: #{GIT_MERGE_COMMIT_FILTERING_OPTIONS.map {|o| "'#{o}'" }.join(', ')}",
                                       optional: true,
                                       default_value: 'include_merges',
                                       verify_block: proc do |value|
                                         matches_option = GIT_MERGE_COMMIT_FILTERING_OPTIONS.any? { |opt| opt.to_s == value }
                                         UI.user_error!("Valid values for :merge_commit_filtering are #{GIT_MERGE_COMMIT_FILTERING_OPTIONS.map {|o| "'#{o}'" }.join(', ')}") unless matches_option
                                       end
                                      )
        ]
      end

      def self.return_value
        "Returns a String containing your formatted git commits"
      end

      def self.author
        ['mfurtak', 'asfalcone', 'Siarhei Fedartsou']
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
