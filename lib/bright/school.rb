module Bright
  class School < Model
    @attribute_names = [:api_id, :name, :number]
    attr_accessor *@attribute_names
  end
end
