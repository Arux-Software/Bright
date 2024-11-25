module Bright
  class EmailAddress < Model
    @attribute_names = [:email_address]
    attr_accessor(*@attribute_names)
  end
end
