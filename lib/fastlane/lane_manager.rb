module Fastlane
  class LaneManager
    # @param platform The name of the platform to execute
    # @param lane_name The name of the lane to execute
    def self.cruise_lane(platform, lane, env = nil)
      fail "lane must be a string" unless lane.is_a?(String) || lane.nil?
      fail "platform must be a string" unless platform.is_a?(String) || platform.nil?

      ff = Fastlane::FastFile.new(File.join(Fastlane::FastlaneFolder.path, "Fastfile"))

      unless (ff.is_platform_block? lane rescue false) # rescue, because this raises an exception if it can't be found at all
        # maybe the user specified a default platform
        # We'll only do this, if the lane specified isn't a platform, as we want to list all platforms then
        platform ||= Actions.lane_context[Actions::SharedValues::DEFAULT_PLATFORM]
      end

      if !platform && lane
        # Either, the user runs a specific lane in root or want to auto complete the available lanes for a platform
        # e.g. `fastlane ios` should list all available iOS actions
        if ff.is_platform_block? lane
          platform = lane
          lane = nil
        end
      end

      platform, lane = choose_lane(ff, platform) unless lane

      load_dot_env(env)

      started = Time.now
      e = nil
      begin
        ff.runner.execute(lane, platform)
      rescue => ex
        Helper.log.info "Variable Dump:".yellow
        Helper.log.info Actions.lane_context
        Helper.log.fatal ex
        e = ex
      end

      duration = ((Time.now - started) / 60.0).round

      finish_fastlane(ff, duration, e)

      ff
    end

    # All the finishing up that needs to be done
    def self.finish_fastlane(ff, duration, error)
      thread = ff.did_finish

      # Finished with all the lanes
      Fastlane::JUnitGenerator.generate(Fastlane::Actions.executed_actions)

      unless error
        thread.join # to wait for the request to be finished
        if duration > 5
          Helper.log.info "fastlane.tools just saved you #{duration} minutes! 🎉".green
        else
          Helper.log.info "fastlane.tools finished successfully 🎉".green
        end
      else
        thread.join # to wait for the request to be finished
        Helper.log.fatal "fastlane finished with errors".red
        fail error
      end
    end

    # Lane chooser if user didn't provide a lane
    # @param platform: is probably nil, but user might have called `fastlane android`, and only wants to list those actions
    def self.choose_lane(ff, platform)
      loop do
        Helper.log.error "You must provide a lane to drive. Available lanes:"
        available = ff.runner.available_lanes(platform)

        available.each_with_index do |lane, index|
          puts "#{index + 1}) #{lane}"
        end

        i = $stdin.gets.strip.to_i - 1
        if i >= 0 && (available[i] rescue nil)
          selection = available[i]
          Helper.log.info "Driving the lane #{selection}. Next time launch fastlane using `fastlane #{selection}`".green
          platform = selection.split(" ")[0]
          lane_name = selection.split(" ")[1]

          unless lane_name # no specific platform, just a root lane
            lane_name = platform
            platform = nil
          end

          return platform, lane_name # yeah
        end

        Helper.log.error "Invalid input. Please enter the number of the lane you want to use".red
      end
    end

    def self.load_dot_env(env)
      require "dotenv"

      Actions.lane_context[Actions::SharedValues::ENVIRONMENT] = env

      # Making sure the default '.env' and '.env.default' get loaded
      env_file = File.join(Fastlane::FastlaneFolder.path || "", ".env")
      env_default_file = File.join(Fastlane::FastlaneFolder.path || "", ".env.default")
      Dotenv.load(env_file, env_default_file)

      # Loads .env file for the environment passed in through options
      if env
        env_file = File.join(Fastlane::FastlaneFolder.path || "", ".env.#{env}")
        Helper.log.info "Loading from '#{env_file}'".green
        Dotenv.overload(env_file)
      end
    end
  end
end
