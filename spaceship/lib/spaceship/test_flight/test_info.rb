require_relative 'base'

module Spaceship::TestFlight
  class TestInfo < Base
    # TestInfo Contains a collection of info for testers. There is one "testInfo" for each locale.
    #
    # For now, when we set a value it sets the same value for all locales
    # When getting a value, we return the first locale values

    attr_accessor :description, :feedback_email, :whats_new

    def description
      raw_data.first['description']
    end

    def description=(value)
      raw_data.each { |locale| locale['description'] = value }
    end

    def feedback_email
      raw_data.first['feedbackEmail']
    end

    def feedback_email=(value)
      raw_data.each { |locale| locale['feedbackEmail'] = value }
    end

    def whats_new
      raw_data.first['whatsNew']
    end

    def whats_new=(value)
      raw_data.each { |locale| locale['whatsNew'] = value }
    end

    def deep_copy
      TestInfo.new(raw_data.map(&:dup))
    end
  end
end
