require "bright/version"
require "bright/errors"

require "bright/model"
require "bright/student"

require "bright/connection"
require "bright/response_collection"

Dir["bright/sis_apis/*.rb"].each {|file| require file }

module Bright

end
