require "bright/version"
require "bright/errors"

require "bright/model"
require "bright/student"

require "bright/connection"
require "bright/sis_api"

Dir["bright/sis_apis/*.rb"].each {|file| require file }

module Bright

end
