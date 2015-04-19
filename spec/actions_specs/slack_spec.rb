describe Fastlane do
  describe Fastlane::FastFile do
    describe "Slack Action" do
      before :each do
        ENV['SLACK_URL'] = 'http://127.0.0.1'
      end

      it "trims long messages to show the bottom of the messages" do
        long_text = "a" * 10000
        expect(Fastlane::Actions::SlackAction.trim_message(long_text).length).to eq(7000)
      end

      it "raises an error if no slack URL is given" do
        ENV.delete 'SLACK_URL'
        expect {
          Fastlane::FastFile.new.parse("lane :test do 
            slack
          end").runner.execute(:test)
        }.to raise_exception('No SLACK_URL given.'.red)
      end

      it "works so perfect, like Slack does" do
        channel = "#myChannel"
        message = "Custom Message"
        lane_name = "lane_name"

        Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::LANE_NAME] = lane_name

        require 'fastlane/actions/slack'
        arguments = Fastlane::ConfigurationHelper.parse(Fastlane::Actions::SlackAction, {
          message: message,
          success: false,
          channel: channel,
          payload: {
            'Build Date' => Time.new.to_s,
            'Built by' => 'Jenkins',
          },
          default_payloads: [:lane, :test_result, :git_branch, :git_author]
        })


        notifier, attachments = Fastlane::Actions::SlackAction.run(arguments)

        expect(notifier.default_payload[:username]).to eq('fastlane')
        expect(notifier.default_payload[:channel]).to eq(channel)

        expect(attachments[:color]).to eq('danger')
        expect(attachments[:text]).to eq(message)

        fields = attachments[:fields]
        expect(fields[1][:title]).to eq('Built by')
        expect(fields[1][:value]).to eq('Jenkins')

        expect(fields[2][:title]).to eq('Lane')
        expect(fields[2][:value]).to eq(lane_name)

        expect(fields[3][:title]).to eq('Test Result')
        expect(fields[3][:value]).to eq('Error')
      end
    end
  end
end
