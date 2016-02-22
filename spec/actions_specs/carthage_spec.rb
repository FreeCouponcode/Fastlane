describe Fastlane do
  describe Fastlane::FastFile do
    describe "Carthage Integration" do
      it "raises an error if command is invalid" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            carthage(
              command: 'thisistest'
            )
          end").runner.execute(:test)
        end.to raise_error("Please pass a valid command. Use one of the following: build, bootstrap, update")
      end

      it "raises an error if configuration is invalid" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            carthage(
              configuration: ''
            )
          end").runner.execute(:test)
        end.to raise_error("Please pass a valid configuration. Use non-empty string")
      end

      it "raises an error if platform is invalid" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            carthage(
              platform: 'thisistest'
            )
          end").runner.execute(:test)
        end.to raise_error("Please pass a valid platform. Use one of the following: all, iOS, Mac, watchOS")
      end

      it "raises an error if verbose is invalid" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            carthage(
              verbose: 'thisistest'
            )
          end").runner.execute(:test)
        end.to raise_error("Please pass a valid value for verbose. Use one of the following: true, false")
      end

      it "raises an error if no_skip_current is invalid" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            carthage(
              no_skip_current: 'thisistest'
            )
          end").runner.execute(:test)
        end.to raise_error("Please pass a valid value for no_skip_current. Use one of the following: true, false")
      end

      it "raises an error if no_checkout is invalid" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            carthage(
              no_checkout: 'thisistest'
            )
          end").runner.execute(:test)
        end.to raise_error("Please pass a valid value for no_checkout. Use one of the following: true, false")
      end

      it "raises an error if no_build is invalid" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            carthage(
              no_build: 'thisistest'
            )
          end").runner.execute(:test)
        end.to raise_error("Please pass a valid value for no_build. Use one of the following: true, false")
      end

      it "raises an error if use_ssh is invalid" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            carthage(
              use_ssh: 'thisistest'
            )
          end").runner.execute(:test)
        end.to raise_error("Please pass a valid value for use_ssh. Use one of the following: true, false")
      end

      it "raises an error if use_submodules is invalid" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            carthage(
              use_submodules: 'thisistest'
            )
          end").runner.execute(:test)
        end.to raise_error("Please pass a valid value for use_submodules. Use one of the following: true, false")
      end

      it "raises an error if no_use_binaries is invalid" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            carthage(
              no_use_binaries: 'thisistest'
            )
          end").runner.execute(:test)
        end.to raise_error("Please pass a valid value for no_use_binaries. Use one of the following: true, false")
      end

      it "default use case is boostrap" do
        result = Fastlane::FastFile.new.parse("lane :test do
            carthage
          end").runner.execute(:test)

        expect(result).to eq("carthage bootstrap")
      end

      it "sets the command to build" do
        result = Fastlane::FastFile.new.parse("lane :test do
            carthage(command: 'build')
          end").runner.execute(:test)

        expect(result).to eq("carthage build")
      end

      it "sets the command to bootstrap" do
        result = Fastlane::FastFile.new.parse("lane :test do
            carthage(command: 'bootstrap')
          end").runner.execute(:test)

        expect(result).to eq("carthage bootstrap")
      end

      it "sets the command to update" do
        result = Fastlane::FastFile.new.parse("lane :test do
            carthage(command: 'update')
          end").runner.execute(:test)

        expect(result).to eq("carthage update")
      end

      it "sets the configuration to Debug" do
        result = Fastlane::FastFile.new.parse("lane :test do
            carthage(
              configuration: 'Debug'
            )
          end").runner.execute(:test)

        expect(result).to eq("carthage bootstrap --configuration Debug")
      end

      it "sets the platform to iOS" do
        result = Fastlane::FastFile.new.parse("lane :test do
            carthage(
              platform: 'iOS'
            )
          end").runner.execute(:test)

        expect(result).to eq("carthage bootstrap --platform iOS")
      end

      it "sets the platform to Mac" do
        result = Fastlane::FastFile.new.parse("lane :test do
            carthage(
              platform: 'Mac'
            )
          end").runner.execute(:test)

        expect(result).to eq("carthage bootstrap --platform Mac")
      end

      it "sets the platform to watchOS" do
        result = Fastlane::FastFile.new.parse("lane :test do
            carthage(
              platform: 'watchOS'
            )
          end").runner.execute(:test)

        expect(result).to eq("carthage bootstrap --platform watchOS")
      end

      it "adds verbose flag to command if verbose is set to true" do
        result = Fastlane::FastFile.new.parse("lane :test do
            carthage(
              verbose: true
            )
          end").runner.execute(:test)

        expect(result).to eq("carthage bootstrap --verbose")
      end

      it "does not add a verbose flag to command if verbose is set to false" do
        result = Fastlane::FastFile.new.parse("lane :test do
            carthage(
              verbose: false
            )
          end").runner.execute(:test)

        expect(result).to eq("carthage bootstrap")
      end

      it "adds no-skip-current flag to command if no_skip_current is set to true" do
        result = Fastlane::FastFile.new.parse("lane :test do
            carthage(
              no_skip_current: true
            )
          end").runner.execute(:test)

        expect(result).to eq("carthage bootstrap --no-skip-current")
      end

      it "doesn't add a no-skip-current flag to command if no_skip_current is set to true" do
        result = Fastlane::FastFile.new.parse("lane :test do
            carthage(
              no_skip_current: false
            )
          end").runner.execute(:test)

        expect(result).to eq("carthage bootstrap")
      end

      it "adds no-checkout flag to command if no_checkout is set to true" do
        result = Fastlane::FastFile.new.parse("lane :test do
            carthage(
              no_checkout: true
            )
          end").runner.execute(:test)

        expect(result).to eq("carthage bootstrap --no-checkout")
      end

      it "doesn't add a no-checkout flag to command if no_checkout is set to true" do
        result = Fastlane::FastFile.new.parse("lane :test do
            carthage(
              no_checkout: false
            )
          end").runner.execute(:test)

        expect(result).to eq("carthage bootstrap")
      end

      it "adds no-build flag to command if no_build is set to true" do
        result = Fastlane::FastFile.new.parse("lane :test do
            carthage(
              no_build: true
            )
          end").runner.execute(:test)

        expect(result).to eq("carthage bootstrap --no-build")
      end

      it "does not add a no-build flag to command if no_build is set to false" do
        result = Fastlane::FastFile.new.parse("lane :test do
            carthage(
              no_build: false
            )
          end").runner.execute(:test)

        expect(result).to eq("carthage bootstrap")
      end

      it "adds use-ssh flag to command if use_ssh is set to true" do
        result = Fastlane::FastFile.new.parse("lane :test do
            carthage(
              use_ssh: true
            )
          end").runner.execute(:test)

        expect(result).to eq("carthage bootstrap --use-ssh")
      end

      it "doesn't add a use-ssh flag to command if use_ssh is set to false" do
        result = Fastlane::FastFile.new.parse("lane :test do
            carthage(
              use_ssh: false
            )
          end").runner.execute(:test)

        expect(result).to eq("carthage bootstrap")
      end

      it "adds use-submodules flag to command if use_submodules is set to true" do
        result = Fastlane::FastFile.new.parse("lane :test do
            carthage(
              use_submodules: true
            )
          end").runner.execute(:test)

        expect(result).to eq("carthage bootstrap --use-submodules")
      end

      it "doesn't add a use-submodules flag to command if use_submodules is set to false" do
        result = Fastlane::FastFile.new.parse("lane :test do
            carthage(
              use_submodules: false
            )
          end").runner.execute(:test)

        expect(result).to eq("carthage bootstrap")
      end

      it "adds no-use-binaries flag to command if no_use_binaries is set to false" do
        result = Fastlane::FastFile.new.parse("lane :test do
            carthage(
              no_use_binaries: true
            )
          end").runner.execute(:test)

        expect(result).to eq("carthage bootstrap --no-use-binaries")
      end

      it "doesn't add a no-use-binaries flag to command if no_use_binaries is set to true" do
        result = Fastlane::FastFile.new.parse("lane :test do
            carthage(
              no_use_binaries: false
            )
          end").runner.execute(:test)

        expect(result).to eq("carthage bootstrap")
      end

      it "works with no parameters" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            carthage
          end").runner.execute(:test)
        end.not_to raise_error
      end

      it "works with valid parameters" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            carthage(
              command: 'bootstrap',
              platform: 'iOS',
              verbose: true,
              no_skip_current: true,
              no_checkout: false,
              no_build: false,
              use_ssh: true,
              use_submodules: true,
              no_use_binaries: true,
            )
          end").runner.execute(:test)
        end.not_to raise_error
      end
    end
  end
end
