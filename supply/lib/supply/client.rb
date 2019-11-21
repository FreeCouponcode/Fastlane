require 'googleauth'
require 'google/apis/androidpublisher_v3'
AndroidPublisher = Google::Apis::AndroidpublisherV3

require 'net/http'

module Supply
  class AbstractGoogleServiceClient
    SCOPE = nil
    SERVICE = nil

    # Connecting with Google
    attr_accessor :client

    def self.make_from_config(params: nil)
      params ||= Supply.config
      service_account_data = self.service_account_authentication(params: params)
      return self.new(service_account_json: service_account_data, params: params)
    end

    # Supply authentication file
    def self.service_account_authentication(params: nil)
      unless params[:json_key] || params[:json_key_data]
        if UI.interactive?
          UI.important("To not be asked about this value, you can specify it using 'json_key'")
          json_key_path = UI.input("The service account json file used to authenticate with Google: ")
          json_key_path = File.expand_path(json_key_path)

          UI.user_error!("Could not find service account json file at path '#{json_key_path}'") unless File.exist?(json_key_path)
          params[:json_key] = json_key_path
        else
          UI.user_error!("Could not load Google authentication. Make sure it has been added as an environment variable in 'json_key' or 'json_key_data'")
        end
      end

      if params[:json_key]
        service_account_json = File.open(File.expand_path(params[:json_key]))
      elsif params[:json_key_data]
        service_account_json = StringIO.new(params[:json_key_data])
      end

      service_account_json
    end

    # Initializes the service and its auth_client using the specified information
    # @param service_account_json: The raw service account Json data
    def initialize(service_account_json: nil, params: nil)
      auth_client = Google::Auth::ServiceAccountCredentials.make_creds(json_key_io: service_account_json, scope: self.class::SCOPE)

      UI.verbose("Fetching a new access token from Google...")

      auth_client.fetch_access_token!

      if FastlaneCore::Env.truthy?("DEBUG")
        Google::Apis.logger.level = Logger::DEBUG
      end

      Google::Apis::ClientOptions.default.application_name = "fastlane (supply client)"
      Google::Apis::ClientOptions.default.application_version = Fastlane::VERSION
      Google::Apis::ClientOptions.default.read_timeout_sec = params[:timeout]
      Google::Apis::ClientOptions.default.open_timeout_sec = params[:timeout]
      Google::Apis::ClientOptions.default.send_timeout_sec = params[:timeout]
      Google::Apis::RequestOptions.default.retries = 5

      service = self.class::SERVICE.new
      service.authorization = auth_client

      if params[:root_url]
        # Google's client expects the root_url string to end with "/".
        params[:root_url] << '/' unless params[:root_url].end_with?('/')
        service.root_url = params[:root_url]
      end

      self.client = service
    end

    private

    def call_google_api
      yield if block_given?
    rescue Google::Apis::Error => e
      error = begin
                JSON.parse(e.body)
              rescue
                nil
              end

      if error
        message = error["error"] && error["error"]["message"]
      else
        message = e.body
      end

      UI.user_error!("Google Api Error: #{e.message} - #{message}")
    end
  end

  class Client < AbstractGoogleServiceClient
    SERVICE = AndroidPublisher::AndroidPublisherService
    SCOPE = AndroidPublisher::AUTH_ANDROIDPUBLISHER

    # Editing something
    # Reference to the entry we're currently editing. Might be nil if don't have one open
    attr_accessor :current_edit
    # Package name of the currently edited element
    attr_accessor :current_package_name

    #####################################################
    # @!group Login
    #####################################################

    def self.service_account_authentication(params: nil)
      if params[:json_key] || params[:json_key_data]
        super(params: params)
      elsif params[:key] && params[:issuer]
        require 'google/api_client/auth/key_utils'
        UI.important("This type of authentication is deprecated. Please consider using JSON authentication instead")
        key = Google::APIClient::KeyUtils.load_from_pkcs12(File.expand_path(params[:key]), 'notasecret')
        cred_json = {
          private_key: key.to_s,
          client_email: params[:issuer]
        }
        service_account_json = StringIO.new(JSON.dump(cred_json))
        service_account_json
      else
        UI.user_error!("No authentication parameters were specified. These must be provided in order to authenticate with Google")
      end
    end

    #####################################################
    # @!group Handling the edit lifecycle
    #####################################################

    # Begin modifying a certain package
    def begin_edit(package_name: nil)
      UI.user_error!("You currently have an active edit") if @current_edit

      self.current_edit = call_google_api { client.insert_edit(package_name) }

      self.current_package_name = package_name
    end

    # Aborts the current edit deleting all pending changes
    def abort_current_edit
      ensure_active_edit!

      call_google_api { client.delete_edit(current_package_name, current_edit.id) }

      self.current_edit = nil
      self.current_package_name = nil
    end

    # Validates the current edit - does not change data on Google Play
    def validate_current_edit!
      ensure_active_edit!

      call_google_api { client.validate_edit(current_package_name, current_edit.id) }
    end

    # Commits the current edit saving all pending changes on Google Play
    def commit_current_edit!
      ensure_active_edit!

      call_google_api { client.commit_edit(current_package_name, current_edit.id) }

      self.current_edit = nil
      self.current_package_name = nil
    end

    #####################################################
    # @!group Getting data
    #####################################################

    # Get a list of all languages - returns the list
    # make sure to have an active edit
    def listings
      ensure_active_edit!

      result = call_google_api { client.list_edit_listings(current_package_name, current_edit.id) }

      return result.listings.map do |row|
        Listing.new(self, row.language, row)
      end
    end

    # Returns the listing for the given language filled with the current values if it already exists
    def listing_for_language(language)
      ensure_active_edit!

      begin
        result = client.get_edit_listing(
          current_package_name,
          current_edit.id,
          language
        )

        return Listing.new(self, language, result)
      rescue Google::Apis::ClientError => e
        return Listing.new(self, language) if e.status_code == 404 # create a new empty listing
        raise
      end
    end

    # Get a list of all APK version codes - returns the list of version codes
    def apks_version_codes
      ensure_active_edit!

      result = call_google_api { client.list_edit_apks(current_package_name, current_edit.id) }

      return Array(result.apks).map(&:version_code)
    end

    # Get a list of all AAB version codes - returns the list of version codes
    def aab_version_codes
      ensure_active_edit!

      result = call_google_api { client.list_edit_bundles(current_package_name, current_edit.id) }

      return Array(result.bundles).map(&:version_code)
    end

    def release_listings(version)
      ensure_active_edit!

      # Verify that tracks have releases
      filtered_tracks = tracks.select { |t| !t.releases.nil? && t.releases.any? { |r| r.name == version } }

      if filtered_tracks.length > 1
        # Production track takes precedence if version is present in multiple tracks
        # E.g.: A release might've been promoted from Alpha/Beta track. This means the release will be present in two or more tracks
        if filtered_tracks.any? { |t| t.track == Supply::Tracks::DEFAULT }
          filtered_tracks = filtered_tracks.select { |t| t.track == Supply::Tracks::DEFAULT }
        else
          # E.g.: A release might be in both Alpha & Beta (not sure if this is possible, just catching if it ever happens), giving Beta precedence.
          filtered_tracks = filtered_tracks.select { |t| t.track == Supply::Tracks::BETA }
        end
      end

      filtered_track = filtered_tracks.first
      if filtered_track.nil?
        UI.user_error!("Unable to find version '#{version}' for '#{current_package_name}' in all tracks. Please double check the version number.")
        return nil
      else
        UI.message("Found '#{version}' in '#{filtered_track.track}' track.")
      end

      filtered_release = filtered_track.releases.first { |r| r.name == version }

      # Since we can release on Alpha/Beta without release notes.
      if filtered_release.release_notes.nil?
        UI.user_error!("Version '#{version}' for '#{current_package_name}' does not seem to have any release notes. Nothing to download.")
        return nil
      end

      return filtered_release.release_notes.map do |row|
        Supply::ReleaseListing.new(filtered_track, filtered_release.name, filtered_release.version_codes, row.language, row.text)
      end
    end

    def latest_version(track)
      latest_version = tracks.select { |t| t.track == Supply::Tracks::DEFAULT }.map(&:releases).flatten.max_by(&:name)

      # Check if user specified '--track' option if version information from 'production' track is nil
      if latest_version.nil? && track == Supply::Tracks::DEFAULT
        UI.user_error!(%(Unable to find latest version information from "#{Supply::Tracks::DEFAULT}" track. Please specify track information by using the '--track' option.))
      else
        latest_version = tracks.select { |t| t.track == track }.map(&:releases).flatten.max_by(&:name)
      end

      return latest_version
    end

    #####################################################
    # @!group Modifying data
    #####################################################

    # Updates or creates the listing for the specified language
    def update_listing_for_language(language: nil, title: nil, short_description: nil, full_description: nil, video: nil)
      ensure_active_edit!

      listing = AndroidPublisher::Listing.new({
        language: language,
        title: title,
        full_description: full_description,
        short_description: short_description,
        video: video
      })

      call_google_api do
        client.update_edit_listing(
          current_package_name,
          current_edit.id,
          language,
          listing
        )
      end
    end

    def upload_apk(path_to_apk)
      ensure_active_edit!

      result_upload = call_google_api do
        client.upload_edit_apk(
          current_package_name,
          current_edit.id,
          upload_source: path_to_apk
        )
      end

      return result_upload.version_code
    end

    def upload_apk_interanl_app_sharing(path_to_apk)
      ensure_active_edit!

      result_upload = call_google_api do
        client.uploadapk_internalappsharingartifact(
          current_package_name,
          upload_source: path_to_apk,
          content_type: "application/octet-stream"
        )
      end

      return result_upload.download_url
    end

    def upload_mapping(path_to_mapping, apk_version_code)
      ensure_active_edit!

      call_google_api do
        client.upload_edit_deobfuscationfile(
          current_package_name,
          current_edit.id,
          apk_version_code,
          "proguard",
          upload_source: path_to_mapping,
          content_type: "application/octet-stream"
        )
      end
    end

    def upload_bundle(path_to_aab)
      ensure_active_edit!

      result_upload = call_google_api do
        client.upload_edit_bundle(
          current_package_name,
          self.current_edit.id,
          upload_source: path_to_aab,
          content_type: "application/octet-stream"
        )
      end

      return result_upload.version_code
    end

    def upload_bundle_interanl_app_sharing(path_to_aab)
      ensure_active_edit!

      result_upload = call_google_api do
        client.uploadbundle_internalappsharingartifact(
          current_package_name,
          upload_source: path_to_aab,
          content_type: "application/octet-stream"
        )
      end

      return result_upload.download_url
    end

    # Get a list of all tracks - returns the list
    def tracks(*tracknames)
      ensure_active_edit!

      all_tracks = call_google_api { client.list_edit_tracks(current_package_name, current_edit.id) }.tracks

      if tracknames.length > 0
        all_tracks = all_tracks.select { |track| tracknames.include?(track.track) }
      end

      return all_tracks
    end

    def update_track(track_name, track_object)
      ensure_active_edit!

      call_google_api do
        client.update_edit_track(
          current_package_name,
          current_edit.id,
          track_name,
          track_object
        )
      end
    end

    # Get list of version codes for track
    def track_version_codes(track)
      ensure_active_edit!

      begin
        result = client.get_edit_track(
          current_package_name,
          current_edit.id,
          track
        )
        return result.releases.flat_map(&:version_codes) || []
      rescue Google::Apis::ClientError => e
        return [] if e.status_code == 404 && e.to_s.include?("trackEmpty")
        raise
      end
    end

    def upload_changelogs(track, track_name)
      ensure_active_edit!

      call_google_api do
        client.update_edit_track(
          current_package_name,
          self.current_edit.id,
          track_name,
          track
        )
      end
    end

    def update_obb(apk_version_code, expansion_file_type, references_version, file_size)
      ensure_active_edit!

      call_google_api do
        client.update_edit_expansionfile(
          current_package_name,
          current_edit.id,
          apk_version_code,
          expansion_file_type,
          AndroidPublisher::ExpansionFile.new(
            references_version: references_version,
            file_size: file_size
          )
        )
      end
    end

    #####################################################
    # @!group Screenshots
    #####################################################

    def fetch_images(image_type: nil, language: nil)
      ensure_active_edit!

      result = call_google_api do
        client.list_edit_images(
          current_package_name,
          current_edit.id,
          language,
          image_type
        )
      end

      urls = (result.images || []).map(&:url)
      images = urls.map do |url|
        uri = URI.parse(url)
        clean_url = [
          uri.scheme,
          uri.userinfo,
          uri.host,
          uri.port,
          uri.path
        ].join

        UI.verbose("Initial URL received: '#{url}'")
        UI.verbose("Removed params ('#{uri.query}') from the URL")
        UI.verbose("URL after removing params: '#{clean_url}'")

        full_url = "#{url}=s0" # '=s0' param ensures full image size is returned (https://github.com/fastlane/fastlane/pull/14322#issuecomment-473012462)
        full_url
      end

      return images
    end

    # @param image_type (e.g. phoneScreenshots, sevenInchScreenshots, ...)
    def upload_image(image_path: nil, image_type: nil, language: nil)
      ensure_active_edit!

      call_google_api do
        client.upload_edit_image(
          current_package_name,
          current_edit.id,
          language,
          image_type,
          upload_source: image_path,
          content_type: 'image/*'
        )
      end
    end

    def clear_screenshots(image_type: nil, language: nil)
      ensure_active_edit!

      call_google_api do
        client.deleteall_edit_image(
          current_package_name,
          current_edit.id,
          language,
          image_type
        )
      end
    end

    def upload_obb(obb_file_path: nil, apk_version_code: nil, expansion_file_type: nil)
      ensure_active_edit!

      call_google_api do
        client.upload_edit_expansionfile(
          current_package_name,
          current_edit.id,
          apk_version_code,
          expansion_file_type,
          upload_source: obb_file_path,
          content_type: 'application/octet-stream'
        )
      end
    end

    private

    def ensure_active_edit!
      UI.user_error!("You need to have an active edit, make sure to call `begin_edit`") unless @current_edit
    end
  end
end
