require 'fileutils'

module Fastlane
  # Enable tab auto completion
  class AutoComplete
    # This method copies the tab auto completion scripts to the user's home folder,
    # while optionally adding custom commands for which to enable auto complete
    # @param [Array] options An array of all options (e.g. --custom fl)
    def self.execute(args, options)
      shell = ENV['SHELL']

      if shell.end_with? "fish"
        fish_completions_dir = "~/.config/fish/completions"

        if UI.interactive?
          confirm = UI.confirm "This will copy a fish script into #{fish_completions_dir} that provides the command tab completion. If the directory does not exist it will be created. Sound good?"
          return unless confirm
        end

        fish_completions_dir = File.expand_path fish_completions_dir
        FileUtils.mkdir_p fish_completions_dir

        completion_script_path = File.join(Fastlane::ROOT, 'lib', 'assets', 'completions', 'completion.fish')
        final_completion_script_path = File.join(fish_completions_dir, 'fastlane.fish')

        FileUtils.cp completion_script_path, final_completion_script_path

        UI.success "Copied! You can now use tab completion for lanes"
      else
        fastlane_conf_dir = "~/.fastlane"

        if UI.interactive?
          confirm = UI.confirm "This will copy a shell script into #{fastlane_conf_dir} that provides the command tab completion. Sound good?"
          return unless confirm
        end

        # create the ~/.fastlane directory
        fastlane_conf_dir = File.expand_path fastlane_conf_dir
        FileUtils.mkdir_p fastlane_conf_dir

        # then copy all of the completions files into it from the gem
        completion_script_path = File.join(Fastlane::ROOT, 'lib', 'assets', 'completions')
        FileUtils.cp_r completion_script_path, fastlane_conf_dir

        custom_commands = options.custom.to_s.split(',')

        if custom_commands.any?
          open("#{fastlane_conf_dir}/completions/completion.bash", 'a') do |file|
            custom_commands.each do |command|
              file.puts "complete -F _fastlane_complete #{command}"
            end
          end

          open("#{fastlane_conf_dir}/completions/completion.zsh", 'a') do |file|
            custom_commands.each do |command|
              file.puts "compctl -K _fastlane_complete #{command}"
            end
          end
        end

        UI.success "Copied! To use auto complete for fastlane, add the following line to your favorite rc file (e.g. ~/.bashrc)"
        UI.important "  . ~/.fastlane/completions/completion.sh"
        UI.success "Don't forget to source that file in your current shell! 🐚"
      end
    end
  end
end
