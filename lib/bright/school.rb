module Bright
  class School < Model
    @attribute_names = [:api_id, :name, :number]
    attr_accessor *@attribute_names
    attr_accessor :address
    
    def address=(address)
      if address.is_a?(Address)
        @address = address
      elsif address.is_a?(Hash)
        @address = Address.new(address)
      end
      @address
    end
    
  end
end
