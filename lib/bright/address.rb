module Bright
  class Address < Model
    @attribute_names = [:street, :apt, :city, :state, :postal_code, :latitude, :longitude, :type]
    attr_accessor(*@attribute_names)

    alias_method :lat, :latitude
    alias_method :lng, :longitude

    def geographical_coordinates
      if latitude and longitude
        "#{latitude},#{longitude}"
      end
    end
  end
end
