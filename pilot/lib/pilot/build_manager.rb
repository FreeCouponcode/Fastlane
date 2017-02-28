module Pilot
  class BuildManager < Manager
    def upload(options)
      start(options)

      options[:changelog] = self.class.truncate_changelog(options[:changelog]) if options[:changelog]

      UI.user_error!("No ipa file given") unless config[:ipa]

      UI.success("Ready to upload new build to TestFlight (App: #{app.apple_id})...")

      platform = fetch_app_platform
      package_path = FastlaneCore::IpaUploadPackageBuilder.new.generate(app_id: app.apple_id,
                                                                      ipa_path: config[:ipa],
                                                                  package_path: "/tmp",
                                                                      platform: platform)

      transporter = FastlaneCore::ItunesTransporter.new(options[:username], nil, false, options[:itc_provider])
      result = transporter.upload(app.apple_id, package_path)

      unless result
        UI.user_error!("Error uploading ipa file, for more information see above")
      end

      UI.success("Successfully uploaded the new binary to iTunes Connect")

      if config[:skip_waiting_for_build_processing]
        UI.important("Skip waiting for build processing")
        UI.important("This means that no changelog will be set and no build will be distributed to testers")
        return
      end

      UI.message("If you want to skip waiting for the processing to be finished, use the `skip_waiting_for_build_processing` option")
      uploaded_build = wait_for_processing_build(options, platform) # this might take a while

      distribute(options, uploaded_build)
    end

    def distribute(options, build = nil)
      start(options)
      if config[:apple_id].to_s.length == 0 and config[:app_identifier].to_s.length == 0
        config[:app_identifier] = UI.input("App Identifier: ")
      end

      if build.nil?
        platform = fetch_app_platform(required: false)
        builds = app.all_processing_builds(platform: platform) + app.builds(platform: platform)
        # sort by upload_date
        builds.sort! { |a, b| a.upload_date <=> b.upload_date }
        build = builds.last
        beta_state = build.external_beta_state
        if build.nil?
          UI.user_error!("No builds found.")
          return
        end
        if build.processing
          UI.user_error!("Build #{build.train_version}(#{build.build_version}) is still processing.")
          return
        end
        if build.testing_status == "External"
          UI.user_error!("Build #{build.train_version}(#{build.build_version}) has already been distributed.")
          return
        end

        type = options[:distribute_external] ? 'External' : 'Internal'
        UI.message("Distributing build #{build.train_version}(#{build.build_version}) from #{build.testing_status} -> #{type}")
      end

      unless config[:update_build_info_on_upload]
        if should_update_build_information(options)
          build.update_build_information!(whats_new: options[:changelog], description: options[:beta_app_description], feedback_email: options[:beta_app_feedback_email])
          UI.success "Successfully set the changelog and/or description for build"
        end
      end
      if beta_state == "waiting" || beta_state == "submitForReview"
        external_available = false
      end

      return if config[:skip_submission]

      distribute_result = distribute_build(build, options, external_available)
      type = options[:distribute_external] ? 'External' : 'Internal'
      # distribute_result returns true if the build was approved for external testing and was turned on.
      # distribute_result returns false if the build was not turned on and only submitted for external review
      if distribute_result
        UI.success("Successfully distributed build to #{type} testers 🚀")
      elsif !distribute_result
        UI.success("Build submitted to beta review")
      end
    end

    def list(options)
      start(options)
      if config[:apple_id].to_s.length == 0 and config[:app_identifier].to_s.length == 0
        config[:app_identifier] = UI.input("App Identifier: ")
      end

      platform = fetch_app_platform(required: false)
      builds = app.all_processing_builds(platform: platform) + app.builds(platform: platform)
      # sort by upload_date
      builds.sort! { |a, b| a.upload_date <=> b.upload_date }
      rows = builds.collect { |build| describe_build(build) }

      puts Terminal::Table.new(
        title: "#{app.name} Builds".green,
        headings: ["Version #", "Build #", "Testing", "Installs", "Sessions", "Beta State"],
        rows: rows
      )
    end

    def self.truncate_changelog(changelog)
      max_changelog_length = 4000
      if changelog && changelog.length > max_changelog_length
        original_length = changelog.length
        bottom_message = "..."
        changelog = "#{changelog[0...max_changelog_length - bottom_message.length]}#{bottom_message}"
        UI.important "Changelog has been truncated since it exceeds Apple's #{max_changelog_length} character limit. It currently contains #{original_length} characters."
      end
      return changelog
    end

    private

    def describe_build(build)
      row = [build.train_version,
             build.build_version,
             build.testing_status,
             build.install_count,
             build.session_count,
             build.external_beta_state]

      return row
    end

    def should_update_build_information(options)
      options[:changelog].to_s.length > 0 or options[:beta_app_description].to_s.length > 0 or options[:beta_app_feedback_email].to_s.length > 0
    end

    # This method will takes care of checking for the processing builds every few seconds
    # @return [Build] The build that we just uploaded
    def wait_for_processing_build(options, platform)
      # the upload date of the new buid
      # we use it to identify the build
      start = Time.now
      wait_processing_interval = config[:wait_processing_interval].to_i
      latest_build = nil
      UI.message("Waiting for iTunes Connect to process the new build")
      must_update_build_info = config[:update_build_info_on_upload]
      loop do
        sleep(wait_processing_interval)

        # before we look for processing builds, we need to ensure that there
        #  is a build train for this application; new applications don't
        #  build trains right away, and if we don't do this check, we will
        #  get break out of this loop and then generate an error later when we
        #  have a nil build
        if app.build_trains(platform: platform).count == 0
          UI.message("New application; waiting for build train to appear on iTunes Connect")
        else
          builds = app.all_processing_builds(platform: platform)
          break if builds.count == 0
          latest_build = builds.last

          if latest_build.valid and must_update_build_info
            # Set the changelog and/or description if necessary
            if should_update_build_information(options)
              latest_build.update_build_information!(whats_new: options[:changelog], description: options[:beta_app_description], feedback_email: options[:beta_app_feedback_email])
              UI.success "Successfully set the changelog and/or description for build"
            end
            must_update_build_info = false
          end

          UI.message("Waiting for iTunes Connect to finish processing the new build (#{latest_build.train_version} - #{latest_build.build_version})")
        end
      end

      UI.user_error!("Error receiving the newly uploaded binary, please check iTunes Connect") if latest_build.nil?
      full_build = nil

      while full_build.nil? || full_build.processing
        # The build's processing state should go from true to false, and be done. But sometimes it goes true -> false ->
        # true -> false, where the second true is transient. This causes a spurious failure. Find build by build_version
        # and ensure it's not processing before proceeding - it had to have already been false before, to get out of the
        # previous loop.
        full_build = app.build_trains(platform: platform)[latest_build.train_version].builds.find do |b|
          b.build_version == latest_build.build_version
        end

        UI.message("Waiting for iTunes Connect to finish processing the new build (#{latest_build.train_version} - #{latest_build.build_version})")
        sleep(wait_processing_interval)
      end

      if full_build && !full_build.processing && full_build.valid
        minutes = ((Time.now - start) / 60).round
        UI.success("Successfully finished processing the build")
        UI.message("You can now tweet: ")
        UI.important("iTunes Connect #iosprocessingtime #{minutes} minutes")
        return full_build
      else
        UI.user_error!("Error: Seems like iTunes Connect didn't properly pre-process the binary")
      end
    end

    def distribute_build(uploaded_build, options, external_available = false)
      UI.message("Distributing new build to testers")

      # Submit for review before external testflight is available
      if options[:distribute_external]
        uploaded_build.client.submit_testflight_build_for_review!(
          app_id: uploaded_build.build_train.application.apple_id,
          train: uploaded_build.build_train.version_string,
          build_number: uploaded_build.build_version,
          platform: uploaded_build.platform
        )
      end

      # Submit for beta testing
      # We need to check if the user is attempting to turn on external builds and the status for external builds
      # If we attempt to make an unapproved external build available iTC will return an error
      if external_available || options[:distribute_external] == 'internal'
        type = options[:distribute_external] ? 'external' : 'internal'
        uploaded_build.build_train.update_testing_status!(true, type, uploaded_build)
        work_status = true
      else
        UI.important('Unable to turn on external testing before beta review approval')
        work_status = false
      end
      return work_status
    end
  end
end
