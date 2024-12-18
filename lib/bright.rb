require_relative "bright/version"
require_relative "bright/errors"

require_relative "bright/helpers/blank_helper"
require_relative "bright/helpers/boolean_parser_helper"

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

require_relative "bright/sis_apis/base"
require_relative "bright/sis_apis/tsis"
require_relative "bright/sis_apis/power_school"
require_relative "bright/sis_apis/aeries"

require_relative "bright/sis_apis/bright_sis"
require_relative "bright/sis_apis/synergy"
require_relative "bright/sis_apis/focus"

require_relative "bright/sis_apis/one_roster"
require_relative "bright/sis_apis/one_roster/infinite_campus"
require_relative "bright/sis_apis/one_roster/skyward"

module Bright
  class << self
    attr_accessor :devmode
  end
end
