module Commander
  # This class override the run method with our custom stack trace handling
  # In particular we want to distinguish between user_error! and crash! (one with, one without stack trace)
  class Runner
    # Code taken from https://github.com/commander-rb/commander/blob/master/lib/commander/runner.rb#L50
    def run!
      require_program :version, :description
      trap('INT') { abort program(:int_message) } if program(:int_message)
      trap('INT') { program(:int_block).call } if program(:int_block)
      global_option('-h', '--help', 'Display help documentation') do
        args = @args - %w(-h --help)
        command(:help).run(*args)
        return
      end
      global_option('-v', '--version', 'Display version information') do
        say version
        return
      end
      parse_global_options
      remove_global_options options, @args

      begin
        run_active_command
      rescue InvalidCommandError => e
        abort "#{e}. Use --help for more information"
      rescue Interrupt => ex
        # We catch it so that the stack trace is hidden by default when using ctrl + c
        if $verbose
          raise ex
        else
          puts "\nCancelled... use --verbose to show the stack trace"
        end
      rescue \
        OptionParser::InvalidOption,
        OptionParser::InvalidArgument,
        OptionParser::MissingArgument => e
        abort e.to_s
      rescue FastlaneCore::Interface::FastlaneError => e # user_error!
        display_user_error!(e, e.message)
      rescue => e # high chance this is actually FastlaneCore::Interface::FastlaneCrash, but can be anything else

        # Some spaceship exception classes implement this method in order to share error information sent by Apple
        # However, fastlane_core and spaceship can not know about each other's classes! To make this information
        # passing work, we use a bit of Ruby duck-typing to check whether the unknown exception type has any of
        # this kind of information to share with us. If so, we'll present it in the manner of a user_error!
        if e.respond_to? :apple_provided_error_info
          message = e.apple_provided_error_info.unshift("Apple provided the following error info:").join("\n\t")
          display_user_error!(e, message)
        else
          FastlaneCore::CrashReporting.handle_crash(e)
          # From https://stackoverflow.com/a/4789702/445598
          # We do this to make the actual error message red and therefore more visible
          reraise_formatted(e, e.message)
        end
      end
    end

    def display_user_error!(e, message)
      if $verbose # with stack trace
        reraise_formatted(e, message)
      else
        abort "\n[!] #{message}".red # without stack trace
      end
    end

    def reraise_formatted(e, message)
      raise e, "[!] #{message}".red, e.backtrace
    end
  end
end
