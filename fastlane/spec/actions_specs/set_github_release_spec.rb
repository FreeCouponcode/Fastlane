describe Fastlane do
  describe Fastlane::FastFile do
    describe "set_github_release" do
      it "sends and receives the right content from GitHub" do
        stub_request(:post, "https://api.github.com/repos/czechboy0/czechboy0.github.io/releases").
          with(body: "{\"tag_name\":\"tag33\",\"name\":\"Awesome Release\",\"body\":\"Bunch of new things :+1:\",\"draft\":false,\"prerelease\":false,\"target_commitish\":\"test\"}",
          headers: { 'Authorization' => 'Basic MTIzNDVhYmNkZQ==', 'Host' => 'api.github.com:443', 'User-Agent' => 'fastlane-set_github_release' }).
          to_return(status: 201, body: File.read("./fastlane/spec/fixtures/requests/github_create_release_response.json"), headers: {})

        result = Fastlane::FastFile.new.parse("lane :test do
          set_github_release(
            repository_name: 'czechboy0/czechboy0.github.io',
            api_token: '12345abcde',
            tag_name: 'tag33',
            name: 'Awesome Release',
            commitish: 'test',
            description: 'Bunch of new things :+1:',
            is_draft: 'false',
            is_prerelease: 'false'
            )
          end").runner.execute(:test)

        expect(result['html_url']).to eq("https://github.com/czechboy0/czechboy0.github.io/releases/tag/tag33")
        expect(result['id']).to eq(1_585_808)
        expect(result).to eq(JSON.parse(File.read("./fastlane/spec/fixtures/requests/github_create_release_response.json")))
      end

      it "returns nil if status code != 201" do
        stub_request(:post, "https://api.github.com/repos/czechboy0/czechboy0.github.io/releases").
          with(body: "{\"tag_name\":\"tag33\",\"name\":\"Awesome Release\",\"body\":\"Bunch of new things :+1:\",\"draft\":false,\"prerelease\":false,\"target_commitish\":\"test\"}",
          headers: { 'Authorization' => 'Basic MTIzNDVhYmNkZQ==', 'Host' => 'api.github.com:443', 'User-Agent' => 'fastlane-set_github_release' }).
          to_return(status: 422, headers: {})

        result = Fastlane::FastFile.new.parse("lane :test do
          set_github_release(
            repository_name: 'czechboy0/czechboy0.github.io',
            api_token: '12345abcde',
            tag_name: 'tag33',
            name: 'Awesome Release',
            commitish: 'test',
            description: 'Bunch of new things :+1:',
            is_draft: false,
            is_prerelease: false
            )
          end").runner.execute(:test)

        expect(result).to eq(nil)
      end

      it "can use a generated changelog as the description" do
        stub_request(:post, "https://api.github.com/repos/czechboy0/czechboy0.github.io/releases").
          with(body: "{\"tag_name\":\"tag33\",\"name\":\"Awesome Release\",\"body\":\"autogenerated changelog\",\"draft\":false,\"prerelease\":false,\"target_commitish\":\"test\"}",
          headers: { 'Authorization' => 'Basic MTIzNDVhYmNkZQ==', 'Host' => 'api.github.com:443', 'User-Agent' => 'fastlane-set_github_release' }).
          to_return(status: 201, body: File.read("./fastlane/spec/fixtures/requests/github_create_release_response.json"), headers: {})

        result = Fastlane::FastFile.new.parse("lane :test do
          Actions.lane_context[SharedValues::FL_CHANGELOG] = 'autogenerated changelog'
          set_github_release(
            repository_name: 'czechboy0/czechboy0.github.io',
            api_token: '12345abcde',
            tag_name: 'tag33',
            name: 'Awesome Release',
            commitish: 'test',
            is_draft: false,
            is_prerelease: false
            )
          end").runner.execute(:test)

        expect(result).to_not be_nil
      end

      it "prefers an explicit description over a generated changelog" do
        stub_request(:post, "https://api.github.com/repos/czechboy0/czechboy0.github.io/releases").
          with(body: "{\"tag_name\":\"tag33\",\"name\":\"Awesome Release\",\"body\":\"explicitly provided\",\"draft\":false,\"prerelease\":false,\"target_commitish\":\"test\"}",
          headers: { 'Authorization' => 'Basic MTIzNDVhYmNkZQ==', 'Host' => 'api.github.com:443', 'User-Agent' => 'fastlane-set_github_release' }).
          to_return(status: 201, body: File.read("./fastlane/spec/fixtures/requests/github_create_release_response.json"), headers: {})

        result = Fastlane::FastFile.new.parse("lane :test do
          Actions.lane_context[SharedValues::FL_CHANGELOG] = 'autogenerated changelog'
          set_github_release(
            repository_name: 'czechboy0/czechboy0.github.io',
            api_token: '12345abcde',
            tag_name: 'tag33',
            name: 'Awesome Release',
            commitish: 'test',
            description: 'explicitly provided',
            is_draft: false,
            is_prerelease: false
            )
          end").runner.execute(:test)

        expect(result).to_not be_nil
      end
    end
  end
end
