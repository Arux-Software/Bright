module Bright
  class Address < Model
    @attribute_names = [:street, :apt, :city, :state, :postal_code, :lattitude, :longitude, :type]
    attr_accessor *@attribute_names
    
    alias lat lattitude
    alias lng longitude
    
    def geographical_coordinates
      if self.lattitude and self.longitude
        "#{self.lattitude},#{self.longitude}"
      end
    end
  end
end


