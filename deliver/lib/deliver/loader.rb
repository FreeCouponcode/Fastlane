require 'fastlane_core/languages'

module Deliver
  module Loader
    # The directory 'appleTV' and `iMessage` are special folders that will cause our screenshot gathering code to iterate
    # through it as well searching for language folders.
    APPLE_TV_DIR_NAME = "appleTV".freeze
    IMESSAGE_DIR_NAME = "iMessage".freeze
    DEFAULT_DIR_NAME = "default".freeze

    EXCEPTION_DIRECTORIES = UploadMetadata::ALL_META_SUB_DIRS.map(&:downcase).freeze

    def self.language_folders(root)
      folders = Dir.glob(File.join(root, '*'))
      
      unless Helper.is_test?
        available_languages = Spaceship::Tunes.client.available_languages
      else
        available_languages = FastlaneCore::Languages::ALL_LANGUAGES
      end
      
      all_languages = (available_languages + [APPLE_TV_DIR_NAME, APPLE_TV_DIR_NAME, IMESSAGE_DIR_NAME, DEFAULT_DIR_NAME]).map(&:downcase).freeze

      selected_folders = folders.select do |path|
        File.directory?(path) && all_languages.include?(File.basename(path).downcase)
      end.sort

      # Gets list of folders that are not supported languages
      rejected_folders = folders.select do |path|
        normalized_path = File.basename(path).downcase
        File.directory?(path) && !all_languages.include?(normalized_path) && !EXCEPTION_DIRECTORIES.include?(normalized_path)
      end.sort

      unless rejected_folders.empty?
        rejected_folders = rejected_folders.map { |path| File.basename(path) }
        UI.user_error! "Unsupport language(s) for screenshots/metadata: #{rejected_folders.join(', ')}\n\nValid languages are: #{all_languages}"
      end

      selected_folders
    end
  end
end
