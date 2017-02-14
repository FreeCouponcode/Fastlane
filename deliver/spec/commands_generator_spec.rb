require 'deliver/commands_generator'
require 'deliver/setup'

describe Deliver::CommandsGenerator do
  describe ":run option handling" do
    it "can use the username short flag from tool options" do
      # leaving out the command name defaults to 'run'
      stub_commander_runner_args(['--description', 'My description', '-u', 'me@it.com'])

      expected_options = FastlaneCore::Configuration.create(Deliver::Options.available_options, {
        description: 'My description',
        username: 'me@it.com'
      })

      fake_runner = "runner"
      expect(Deliver::Runner).to receive(:new) do |actual_options|
        expect(expected_options._values).to eq(actual_options._values)
      end.and_return(fake_runner)
      expect(fake_runner).to receive(:run)

      Deliver::CommandsGenerator.start
    end

    it "can use the app_identifier flag from tool options" do
      # leaving out the command name defaults to 'run'
      stub_commander_runner_args(['--description', 'My description', '--app_identifier', 'abcd'])

      expected_options = FastlaneCore::Configuration.create(Deliver::Options.available_options, {
        description: 'My description',
        app_identifier: 'abcd'
      })

      fake_runner = "runner"
      expect(Deliver::Runner).to receive(:new) do |actual_options|
        expect(expected_options._values).to eq(actual_options._values)
      end.and_return(fake_runner)
      expect(fake_runner).to receive(:run)

      Deliver::CommandsGenerator.start
    end
  end

  describe ":submit_build option handling" do
    it "can use the username short flag from tool options" do
      stub_commander_runner_args(['submit_build', '--description', 'My description', '-u', 'me@it.com'])

      expected_options = FastlaneCore::Configuration.create(Deliver::Options.available_options, {
        description: 'My description',
        username: 'me@it.com',
        submit_for_review: true,
        build_number: 'latest'
      })

      expect_run_with_options(expected_options)

      Deliver::CommandsGenerator.start
    end

    it "can use the app_identifier flag from tool options" do
      stub_commander_runner_args(['submit_build', '--description', 'My description', '--app_identifier', 'abcd'])

      expected_options = FastlaneCore::Configuration.create(Deliver::Options.available_options, {
        description: 'My description',
        app_identifier: 'abcd',
        submit_for_review: true,
        build_number: 'latest'
      })

      expect_run_with_options(expected_options)

      Deliver::CommandsGenerator.start
    end
  end

  describe ":init option handling" do
    it "can use the username short flag from tool options" do
      stub_commander_runner_args(['init', '--description', 'My description', '-u', 'me@it.com'])

      expected_options = FastlaneCore::Configuration.create(Deliver::Options.available_options, {
        description: 'My description',
        username: 'me@it.com'
      })

      expect(Deliver::Runner).to receive(:new) do |actual_options|
        expect(expected_options._values).to eq(actual_options._values)
      end

      fake_setup = "setup"
      expect(Deliver::Setup).to receive(:new).and_return(fake_setup)
      expect(fake_setup).to receive(:run) do |actual_options|
        expect(expected_options._values).to eq(actual_options._values)
      end

      Deliver::CommandsGenerator.start
    end

    it "can use the app_identifier flag from tool options" do
      stub_commander_runner_args(['init', '--description', 'My description', '--app_identifier', 'abcd'])

      expected_options = FastlaneCore::Configuration.create(Deliver::Options.available_options, {
        description: 'My description',
        app_identifier: 'abcd'
      })

      expect(Deliver::Runner).to receive(:new) do |actual_options|
        expect(expected_options._values).to eq(actual_options._values)
      end

      fake_setup = "setup"
      expect(Deliver::Setup).to receive(:new).and_return(fake_setup)
      expect(fake_setup).to receive(:run) do |actual_options|
        expect(expected_options._values).to eq(actual_options._values)
      end

      Deliver::CommandsGenerator.start
    end
  end

  describe ":generate_summary option handling" do
    it "can use the username short flag from tool options" do
      stub_commander_runner_args(['generate_summary', '--description', 'My description', '-u', 'me@it.com', '-f', 'true'])

      expected_options = FastlaneCore::Configuration.create(Deliver::Options.available_options, {
        description: 'My description',
        username: 'me@it.com',
        force: true
      })

      expect(Deliver::Runner).to receive(:new) do |actual_options|
        expect(expected_options._values).to eq(actual_options._values)
      end

      fake_generate_summary = "generate_summary"
      expect(Deliver::GenerateSummary).to receive(:new).and_return(fake_generate_summary)
      expect(fake_generate_summary).to receive(:run) do |actual_options|
        expect(expected_options._values).to eq(actual_options._values)
      end

      Deliver::CommandsGenerator.start
    end

    it "can use the app_identifier flag from tool options" do
      stub_commander_runner_args(['generate_summary', '--description', 'My description', '--app_identifier', 'abcd', '-f', 'true'])

      expected_options = FastlaneCore::Configuration.create(Deliver::Options.available_options, {
        description: 'My description',
        app_identifier: 'abcd',
        force: true
      })

      expect(Deliver::Runner).to receive(:new) do |actual_options|
        expect(expected_options._values).to eq(actual_options._values)
      end

      fake_generate_summary = "generate_summary"
      expect(Deliver::GenerateSummary).to receive(:new).and_return(fake_generate_summary)
      expect(fake_generate_summary).to receive(:run) do |actual_options|
        expect(expected_options._values).to eq(actual_options._values)
      end

      Deliver::CommandsGenerator.start
    end
  end

  describe ":download_screenshots option handling" do
    it "can use the username short flag from tool options" do
      stub_commander_runner_args(['download_screenshots', '--description', 'My description', '-u', 'me@it.com', '-w', 'screenshots/path'])

      expected_options = FastlaneCore::Configuration.create(Deliver::Options.available_options, {
        description: 'My description',
        username: 'me@it.com',
        screenshots_path: 'screenshots/path'
      })

      expect(Deliver::Runner).to receive(:new) do |actual_options|
        expect(expected_options._values).to eq(actual_options._values)
      end

      expect(Deliver::DownloadScreenshots).to receive(:run) do |actual_options, screenshots_path|
        expect(expected_options._values).to eq(actual_options._values)
        expect(screenshots_path).to eq('screenshots/path')
      end

      Deliver::CommandsGenerator.start
    end

    it "can use the app_identifier flag from tool options" do
      stub_commander_runner_args(['download_screenshots', '--description', 'My description', '--app_identifier', 'abcd', '-w', 'screenshots/path'])

      expected_options = FastlaneCore::Configuration.create(Deliver::Options.available_options, {
        description: 'My description',
        app_identifier: 'abcd',
        screenshots_path: 'screenshots/path'
      })

      expect(Deliver::Runner).to receive(:new) do |actual_options|
        expect(expected_options._values).to eq(actual_options._values)
      end

      expect(Deliver::DownloadScreenshots).to receive(:run) do |actual_options, screenshots_path|
        expect(expected_options._values).to eq(actual_options._values)
        expect(screenshots_path).to eq('screenshots/path')
      end

      Deliver::CommandsGenerator.start
    end
  end

  describe ":download_metadata option handling" do
    it "can use the app_identifier flag from tool options" do
      stub_commander_runner_args(['download_metadata', '--description', 'My description', '--app_identifier', 'abcd', '-m', 'metadata/path'])

      expected_options = FastlaneCore::Configuration.create(Deliver::Options.available_options, {
        description: 'My description',
        app_identifier: 'abcd',
        metadata_path: 'metadata/path'
      })

      fake_app = "fake_app"
      expect(fake_app).to receive(:latest_version).and_return('1.0.0')

      expect(Deliver::Runner).to receive(:new) do |actual_options|
        expect(expected_options._values).to eq(actual_options._values)
        # ugly work-around to do the work that DetectValues would normally do
        actual_options[:app] = fake_app
      end

      fake_setup = "fake_setup"
      expect(Deliver::Setup).to receive(:new).and_return(fake_setup)
      expect(fake_setup).to receive(:generate_metadata_files) do |version, metadata_path|
        expect(version).to eq('1.0.0')
        expect(metadata_path).to eq('metadata/path')
      end

      # ENV var is needed to prevent user prompting for confirmation
      with_env_values('DELIVER_FORCE_OVERWRITE' => '1') do
        Deliver::CommandsGenerator.start
      end
    end
  end
end
