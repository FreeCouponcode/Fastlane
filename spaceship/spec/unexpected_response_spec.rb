require 'spec_helper'
require 'colored'

describe Spaceship::Client::UnexpectedResponse do
  describe '#handle_response' do
    def stub_response_body(body)
      allow(response).to receive(:body).and_return(body)
    end

    let(:response) { "response" }

    it 'should raise UnexpectedResponse when the response does not contain embedded error info' do
      stub_response_body({'something' => 'whatever'})

      expect do
        Spaceship::Client::UnexpectedResponse.handle_response!(response)
      end.to raise_error(Spaceship::Client::UnexpectedResponse, {'something' => 'whatever'}.to_s)
    end

    it 'should use user_error! to re-raise if an Apple-provided error message is present in the response and $verbose is true' do
      stub_response_body({'userString' => 'User string', 'resultString' => 'Result string'})

      with_verbosity(true) do
        expect do
          Spaceship::Client::UnexpectedResponse.handle_response!(response)
        end.to raise_error(Spaceship::Client::UnexpectedResponse, "[!] Apple returned an unexpected response:\nResult string\nUser string".red)
      end
    end

    it 'should use user_error! to abort if an Apple-provided error message is present in the response and $verbose is false' do
      stub_response_body({'userString' => 'User string', 'resultString' => 'Result string'})

      with_verbosity(false) do
        expect(Spaceship::Client::UnexpectedResponse).to receive(:abort).with("\n[!] Apple returned an unexpected response:\nResult string\nUser string".red)

        Spaceship::Client::UnexpectedResponse.handle_response!(response)
      end
    end
  end
end
