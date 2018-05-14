module Bright
  class PhoneNumber < Model
    @attribute_names = [:phone_number, :type]
    attr_accessor *@attribute_names
    TYPES = ["Cell", "Home", "Work", "Other"]
    
  end
end
