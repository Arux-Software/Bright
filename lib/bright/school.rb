module Bright
  class School < Model
    @attribute_names = [:api_id, :name, :number, :state_id, :low_grade, :high_grade]
    attr_accessor *@attribute_names
    attr_accessor :address, :phone_number

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
