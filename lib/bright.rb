require_relative "bright/version"
require_relative "bright/errors"

require_relative "bright/helpers/blank_helper.rb"
require_relative "bright/helpers/boolean_parser_helper.rb"

require_relative "bright/model"
require_relative "bright/student"
require_relative "bright/address"
require_relative "bright/phone_number"
require_relative "bright/email_address"
require_relative "bright/enrollment"
require_relative "bright/school"
require_relative "bright/contact"


require_relative "bright/connection"
require_relative "bright/response_collection"
require_relative "bright/cursor_response_collection"

require_relative "bright/sis_apis/base.rb"
require_relative "bright/sis_apis/tsis.rb"
require_relative "bright/sis_apis/power_school.rb"
require_relative "bright/sis_apis/aeries.rb"
require_relative "bright/sis_apis/infinite_campus.rb"
require_relative "bright/sis_apis/skyward.rb"
require_relative "bright/sis_apis/bright_sis.rb"
require_relative "bright/sis_apis/synergy.rb"

module Bright
  class << self
    attr_accessor :devmode
  end
end
