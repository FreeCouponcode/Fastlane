module TestFlight
  class Build < Base
    # @example
    #   "com.sample.app"
    attr_accessor :bundle_id

    # @example
    #   "testflight.build.state.testing.active"
    # @example
    #   "testflight.build.state.processing"
    attr_accessor :internal_state

    # @example
    #   "testflight.build.state.submit.ready"
    # @example
    #   "testflight.build.state.processing"
    attr_accessor :external_state

    # Internal build ID (int)
    # @example
    #   19285309
    attr_accessor :id

    # @example
    #   "1.0"
    attr_accessor :train_version

    # @example
    #   "152"
    attr_accessor :build_version

    attr_accessor :beta_review_info

    attr_accessor :export_compliance

    attr_accessor :test_info

    attr_accessor :install_count
    attr_accessor :invite_count
    attr_accessor :crash_count

    attr_accessor :did_notify

    attr_accessor :upload_date

    attr_mapping({
      'bundleId' => :bundle_id,
      'trainVersion' => :train_version,
      'buildVersion' => :build_version,
      'betaReviewInfo' => :beta_review_info,
      'exportCompliance' => :export_compliance,
      'internalState' => :internal_state,
      'externalState' => :external_state,
      'testInfo' => :test_info,
      'installCount' => :install_count,
      'inviteCount' => :invite_count,
      'crashCount' => :crash_count,
      'didNotify' => :did_notify,
      'uploadDate' => :upload_date,
      'id' => :id
    })


    def self.factory(attrs)
      # Parse the dates
      # rubocop:disable Style/RescueModifier
      attrs['uploadDate'] = (Time.parse(attrs['uploadDate']) rescue attrs['uploadDate'])
      # rubocop:enable Style/RescueModifier

      obj = self.new(attrs)
    end

    def self.find(app_id, build_id)
      attrs = client.get_build(app_id, build_id)
      self.new(attrs) if attrs
    end

    # All build trains, each with its builds
    # @example
    #   {
    #     "1.0" => [
    #       Build1,
    #       Build2
    #     ],
    #     "1.1" => [
    #       Build3
    #     ]
    #   }
    def self.all(app_id, platform: nil)
      build_trains = client.all_build_trains(app_id: app_id, platform: platform)
      result = {}
      build_trains.each do |train_version|
        builds = client.all_builds_for_train(app_id: app_id, platform: platform, train_version: train_version)
        result[train_version] = builds.collect do |current_build|
          self.factory(current_build) # TODO: when inspecting those builds, something's wrong, it doesn't expose the attributes. I don't know why
        end
      end
      return result
    end

    # Just the builds, as a flat array, that are still processing
    def self.all_processing_builds(app_id, platform: nil)
      all_builds = self.all(app_id, platform: platform)
      result = []
      all_builds.each do |train_version, builds|
        result += builds.find_all do |build|
          build.external_state == "testflight.build.state.processing"
        end
      end
      return result
    end

    # @param train_version and build_version are used internally
    def self.wait_for_build_processing_to_be_complete(app_id, train_version: nil, build_version: nil, platform: nil)
      # TODO: do we want to move this somewhere else?
      processing = all_processing_builds(app_id, platform: platform)
      return if processing.count == 0

      if train_version && build_version
        # We already have a specific build we wait for, use that one
        build = processing.find { |b| b.train_version == train_version && b.build_version == build_version }
        return if build.nil? # wohooo, the build doesn't show up in the `processing` list any more, we're good
      else
        # Fetch the most recent build, as we want to wait for that one
        # any previous builds might be there since they're stuck
        build = processing.sort_by { |b| b.upload_date }.last
      end

      # We got the build we want to wait for, wait now...
      sleep(10)
      # TODO: we really should move this somewhere else, so that we can print out what we used to print
      # UI.message("Waiting for iTunes Connect to finish processing the new build (#{build.train_version} - #{build.build_version})")
      # we don't have access to FastlaneCore::UI in spaceship
      wait_for_build_processing_to_be_complete(app_id,
                                               build_version: build.build_version,
                                               train_version: build.train_version,
                                               platform: platform)

      # Also when it's finished we used to do
      # UI.success("Successfully finished processing the build")
      # UI.message("You can now tweet: ")
      # UI.important("iTunes Connect #iosprocessingtime #{minutes} minutes")
    end

    def beta_review_info
      BetaReviewInfo.new(super) # TODO: please document on what this `super` does, I didn't see it before in this context
    end

    def export_compliance
      ExportCompliance.new(super)
    end

    def test_info
      TestInfo.new(super)
    end
  end
end
