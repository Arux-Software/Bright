module Bright
  class Address < Model
    @attribute_names = [:street, :apt, :city, :state, :postal_code, :latitude, :longitude, :type]
    attr_accessor *@attribute_names

    alias lat latitude
    alias lng longitude

    def geographical_coordinates
      if self.latitude and self.longitude
        "#{self.latitude},#{self.longitude}"
      end
    end
  end
end
