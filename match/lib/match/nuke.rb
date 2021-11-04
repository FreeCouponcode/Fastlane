require 'terminal-table'

require 'spaceship'
require 'fastlane_core/provisioning_profile'
require 'fastlane_core/print_table'

require_relative 'module'

require_relative 'storage'
require_relative 'encryption'

module Match
  class Nuke
    attr_accessor :params
    attr_accessor :type

    attr_accessor :certs
    attr_accessor :profiles
    attr_accessor :files

    attr_accessor :storage
    attr_accessor :encryption

    def run(params, type: nil)
      self.params = params
      self.type = type

      update_optional_values_depending_on_storage_type(params)

      spaceship_login

      self.storage = Storage.for_mode(params[:storage_mode], {
        git_url: params[:git_url],
        shallow_clone: params[:shallow_clone],
        skip_docs: params[:skip_docs],
        git_branch: params[:git_branch],
        git_full_name: params[:git_full_name],
        git_user_email: params[:git_user_email],

        git_private_key: params[:git_private_key],
        git_basic_authorization: params[:git_basic_authorization],
        git_bearer_authorization: params[:git_bearer_authorization],

        clone_branch_directly: params[:clone_branch_directly],
        google_cloud_bucket_name: params[:google_cloud_bucket_name].to_s,
        google_cloud_keys_file: params[:google_cloud_keys_file].to_s,
        google_cloud_project_id: params[:google_cloud_project_id].to_s,
        s3_region: params[:s3_region].to_s,
        s3_access_key: params[:s3_access_key].to_s,
        s3_secret_access_key: params[:s3_secret_access_key].to_s,
        s3_bucket: params[:s3_bucket].to_s,
        team_id: params[:team_id] || Spaceship::ConnectAPI.client.portal_team_id
      })
      self.storage.download

      # After the download was complete
      self.encryption = Encryption.for_storage_mode(params[:storage_mode], {
        git_url: params[:git_url],
        working_directory: storage.working_directory
      })
      self.encryption.decrypt_files if self.encryption

      had_app_identifier = self.params.fetch(:app_identifier, ask: false)
      self.params[:app_identifier] = '' # we don't really need a value here
      FastlaneCore::PrintTable.print_values(config: params,
                                         hide_keys: [:app_identifier],
                                             title: "Summary for match nuke #{Fastlane::VERSION}")

      prepare_list
      filter_by_cert
      print_tables

      if params[:readonly]
        UI.user_error!("`fastlane match nuke` doesn't delete anything when running with --readonly enabled")
      end

      if (self.certs + self.profiles + self.files).count > 0
        unless params[:skip_confirmation]
          UI.error("---")
          UI.error("Are you sure you want to completely delete and revoke all the")
          UI.error("certificates and provisioning profiles listed above? (y/n)")
          UI.error("Warning: By nuking distribution, both App Store and Ad Hoc profiles will be deleted") if type == "distribution"
          UI.error("Warning: The :app_identifier value will be ignored - this will delete all profiles for all your apps!") if had_app_identifier
          UI.error("---")
        end
        if params[:skip_confirmation] || UI.confirm("Do you really want to nuke everything listed above?")
          nuke_it_now!
          UI.success("Successfully cleaned your account ♻️")
        else
          UI.success("Cancelled nuking #thanks 🏠 👨 ‍👩 ‍👧")
        end
      else
        UI.success("No relevant certificates or provisioning profiles found, nothing to nuke here :)")
      end
    end

    # Be smart about optional values here
    # Depending on the storage mode, different values are required
    def update_optional_values_depending_on_storage_type(params)
      if params[:storage_mode] != "git"
        params.option_for_key(:git_url).optional = true
      end
    end

    def spaceship_login
      if (api_token = Spaceship::ConnectAPI::Token.from(hash: params[:api_key], filepath: params[:api_key_path]))
        UI.message("Creating authorization token for App Store Connect API")
        Spaceship::ConnectAPI.token = api_token
      elsif !Spaceship::ConnectAPI.token.nil?
        UI.message("Using existing authorization token for App Store Connect API")
      else
        Spaceship::ConnectAPI.login(params[:username], use_portal: true, use_tunes: false, portal_team_id: params[:team_id], team_name: params[:team_name])
      end

      if Spaceship::ConnectAPI.client.in_house? && (type == "distribution" || type == "enterprise")
        UI.error("---")
        UI.error("⚠️ Warning: This seems to be an Enterprise account!")
        UI.error("By nuking your account's distribution, all your apps deployed via ad-hoc will stop working!") if type == "distribution"
        UI.error("By nuking your account's enterprise, all your in-house apps will stop working!") if type == "enterprise"
        UI.error("---")

        UI.user_error!("Enterprise account nuke cancelled") unless UI.confirm("Do you really want to nuke your Enterprise account?")
      end
    end

    # Collect all the certs/profiles
    def prepare_list
      UI.message("Fetching certificates and profiles...")
      cert_type = Match.cert_type_sym(type)
      cert_types = [cert_type]

      prov_types = []
      prov_types = [:development] if cert_type == :development
      prov_types = [:appstore, :adhoc, :developer_id] if cert_type == :distribution
      prov_types = [:enterprise] if cert_type == :enterprise

      # Get all iOS and macOS profile
      self.profiles = []
      prov_types.each do |prov_type|
        types = profile_types(prov_type)
        # Filtering on 'profileType' seems to be undocumented as of 2020-07-30
        # but works on both web session and official API
        self.profiles += Spaceship::ConnectAPI::Profile.all(filter: { profileType: types.join(",") }, includes: "certificates")
      end

      # Gets the main and additional cert types
      cert_types += (params[:additional_cert_types] || []).map do |ct|
        Match.cert_type_sym(ct)
      end

      # Gets all the certs form the cert types
      self.certs = []
      self.certs += cert_types.map do |ct|
        certificate_type(ct).flat_map do |cert|
          Spaceship::ConnectAPI::Certificate.all(filter: { certificateType: cert })
        end
      end.flatten

      # Finds all the .cer and .p12 files in the file storage
      certs = []
      keys = []
      cert_types.each do |ct|
        certs += self.storage.list_files(file_name: ct.to_s, file_ext: "cer")
        keys += self.storage.list_files(file_name: ct.to_s, file_ext: "p12")
      end

      # Finds all the iOS and macOS profofiles in the file storage
      profiles = []
      prov_types.each do |prov_type|
        profiles += self.storage.list_files(file_name: prov_type.to_s, file_ext: "mobileprovision")
        profiles += self.storage.list_files(file_name: prov_type.to_s, file_ext: "provisionprofile")
      end

      self.files = certs + keys + profiles
    end

    def filter_by_cert
      return if self.params[:force]

      puts("")
      if self.certs.count > 0
        rows = self.certs.each_with_index.collect do |cert, i|
          cert_expiration = cert.expiration_date.nil? ? "Unknown" : Time.parse(cert.expiration_date).strftime("%Y-%m-%d")
          [i+1, cert.name, cert.id, cert.class.to_s.split("::").last, cert_expiration]
        end
        puts(Terminal::Table.new({
          title: "Certificates that can be revoked".green,
          headings: ["Option", "Name", "ID", "Type", "Expires"],
          rows: FastlaneCore::PrintTable.transform_output(rows)
        }))
        puts("")
      end

      if UI.confirm("Do you want to nuke specific certificates and their associated profiles?")
        input_indexes = UI.input("Enter the \"Option\" number(s) from the table above? (comma-separated)").split(',')

        new_certs = input_indexes.map do |index|
          self.certs[index.to_i - 1]
        end

        self.certs = new_certs

        # Do profile selection logic
        cert_ids = self.certs.map(&:id)
        self.profiles = self.profiles.select do |profile|
          profile_cert_ids = profile.certificates.map(&:id)
          (cert_ids & profile_cert_ids).any?
        end

        # Do file selection logic
        self.files = self.files.select do |f|
          filename_and_ext = File.basename(f)
          filename = File.basename(f, ".*")

          select = self.certs.find do |cert|
            filename == cert.id.to_s
          end || self.profiles.find do |profile|
            # might need to check extension if mac or catalyst
            profile.name.end_with?(filename.gsub("_", " "))
          end

          select
        end
      end
    end

    # Print tables to ask the user
    def print_tables
      puts("")
      if self.certs.count > 0
        rows = self.certs.collect do |cert|
          cert_expiration = cert.expiration_date.nil? ? "Unknown" : Time.parse(cert.expiration_date).strftime("%Y-%m-%d")
          [cert.name, cert.id, cert.class.to_s.split("::").last, cert_expiration]
        end
        puts(Terminal::Table.new({
          title: "Certificates that are going to be revoked".green,
          headings: ["Name", "ID", "Type", "Expires"],
          rows: FastlaneCore::PrintTable.transform_output(rows)
        }))
        puts("")
      end

      if self.profiles.count > 0
        rows = self.profiles.collect do |p|
          status = p.valid? ? p.profile_state.green : p.profile_state.red

          # Expires is sometimes nil
          expires = p.expiration_date ? Time.parse(p.expiration_date).strftime("%Y-%m-%d") : nil
          [p.name, p.id, status, p.profile_type, expires]
        end
        puts(Terminal::Table.new({
          title: "Provisioning Profiles that are going to be revoked".green,
          headings: ["Name", "ID", "Status", "Type", "Expires"],
          rows: FastlaneCore::PrintTable.transform_output(rows)
        }))
        puts("")
      end

      if self.files.count > 0
        rows = self.files.collect do |f|
          components = f.split(File::SEPARATOR)[-3..-1]

          # from "...1o7xtmh/certs/distribution/8K38XUY3AY.cer" to "distribution cert"
          file_type = components[0..1].reverse.join(" ")[0..-2]

          [file_type, components[2]]
        end

        puts(Terminal::Table.new({
          title: "Files that are going to be deleted".green + "\n" + self.storage.human_readable_description,
          headings: ["Type", "File Name"],
          rows: rows
        }))
        puts("")
      end
    end

    def nuke_it_now!
      UI.header("Deleting #{self.profiles.count} provisioning profiles...") unless self.profiles.count == 0
      self.profiles.each do |profile|
        UI.message("Deleting profile '#{profile.name}' (#{profile.id})...")
        begin
          profile.delete!
        rescue => ex
          UI.message(ex.to_s)
        end
        UI.success("Successfully deleted profile")
      end

      UI.header("Revoking #{self.certs.count} certificates...") unless self.certs.count == 0
      self.certs.each do |cert|
        UI.message("Revoking certificate '#{cert.name}' (#{cert.id})...")
        begin
          cert.delete!
        rescue => ex
          UI.message(ex.to_s)
        end
        UI.success("Successfully deleted certificate")
      end

      files_to_delete = delete_files! if self.files.count > 0
      files_to_delete ||= []

      self.encryption.encrypt_files if self.encryption

      if files_to_delete.count > 0
        # Now we need to save all this to the storage too, if needed
        message = ["[fastlane]", "Nuked", "files", "for", type.to_s].join(" ")
        self.storage.save_changes!(files_to_commit: [],
                                   files_to_delete: files_to_delete,
                                   custom_message: message)
      else
        UI.message("Your storage had no files to be deleted. This happens when you run `nuke` with an empty storage. Nothing to be worried about!")
      end
    end

    private

    def delete_files!
      UI.header("Deleting #{self.files.count} files from the storage...")

      return self.files.collect do |file|
        UI.message("Deleting file '#{File.basename(file)}'...")

        # Check if the profile is installed on the local machine
        if file.end_with?("mobileprovision")
          parsed = FastlaneCore::ProvisioningProfile.parse(file)
          uuid = parsed["UUID"]
          path = Dir[File.join(FastlaneCore::ProvisioningProfile.profiles_path, "#{uuid}.mobileprovision")].last
          File.delete(path) if path
        end

        File.delete(file)
        UI.success("Successfully deleted file")

        file
      end
    end

    # The kind of certificate we're interested in
    def certificate_type(type)
      case type.to_sym
      when :mac_installer_distribution
        return [
          Spaceship::ConnectAPI::Certificate::CertificateType::MAC_INSTALLER_DISTRIBUTION
        ]
      when :distribution
        return [
          Spaceship::ConnectAPI::Certificate::CertificateType::MAC_APP_DISTRIBUTION,
          Spaceship::ConnectAPI::Certificate::CertificateType::IOS_DISTRIBUTION,
          Spaceship::ConnectAPI::Certificate::CertificateType::DISTRIBUTION
        ]
      when :development
        return [
          Spaceship::ConnectAPI::Certificate::CertificateType::MAC_APP_DEVELOPMENT,
          Spaceship::ConnectAPI::Certificate::CertificateType::IOS_DEVELOPMENT,
          Spaceship::ConnectAPI::Certificate::CertificateType::DEVELOPMENT
        ]
      when :enterprise
        return [
          Spaceship::ConnectAPI::Certificate::CertificateType::IOS_DISTRIBUTION
        ]
      else
        raise "Unknown type '#{type}'"
      end
    end

    # The kind of provisioning profile we're interested in
    def profile_types(prov_type)
      case prov_type.to_sym
      when :appstore
        return [
          Spaceship::ConnectAPI::Profile::ProfileType::IOS_APP_STORE,
          Spaceship::ConnectAPI::Profile::ProfileType::MAC_APP_STORE,
          Spaceship::ConnectAPI::Profile::ProfileType::TVOS_APP_STORE,
          Spaceship::ConnectAPI::Profile::ProfileType::MAC_CATALYST_APP_STORE
        ]
      when :development
        return [
          Spaceship::ConnectAPI::Profile::ProfileType::IOS_APP_DEVELOPMENT,
          Spaceship::ConnectAPI::Profile::ProfileType::MAC_APP_DEVELOPMENT,
          Spaceship::ConnectAPI::Profile::ProfileType::TVOS_APP_DEVELOPMENT,
          Spaceship::ConnectAPI::Profile::ProfileType::MAC_CATALYST_APP_DEVELOPMENT
        ]
      when :enterprise
        return [
          Spaceship::ConnectAPI::Profile::ProfileType::IOS_APP_INHOUSE,
          Spaceship::ConnectAPI::Profile::ProfileType::TVOS_APP_INHOUSE
        ]
      when :adhoc
        return [
          Spaceship::ConnectAPI::Profile::ProfileType::IOS_APP_ADHOC,
          Spaceship::ConnectAPI::Profile::ProfileType::TVOS_APP_ADHOC
        ]
      when :developer_id
        return [
          Spaceship::ConnectAPI::Profile::ProfileType::MAC_APP_DIRECT,
          Spaceship::ConnectAPI::Profile::ProfileType::MAC_CATALYST_APP_DIRECT
        ]
      else
        raise "Unknown provisioning type '#{prov_type}'"
      end
    end
  end
end
