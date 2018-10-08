require_relative '../../../fastlane_core/lib/fastlane_core/require_relative_helper'

require_relative internal('fastlane_core/ui/ui')
require_relative internal('fastlane_core/helper')

module Sigh
  # Use this to just setup the configuration attribute and set it later somewhere else
  class << self
    attr_accessor :config
  end

  Helper = FastlaneCore::Helper # you gotta love Ruby: Helper.* should use the Helper class contained in FastlaneCore
  UI = FastlaneCore::UI
  ROOT = Pathname.new(File.expand_path('../../..', __FILE__))

  ENV['FASTLANE_TEAM_ID'] ||= ENV["SIGH_TEAM_ID"]
  ENV['DELIVER_USER'] ||= ENV["SIGH_USERNAME"]
end
