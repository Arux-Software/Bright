module Bright
  class PhoneNumber < Model
    @attribute_names = [:phone_number, :extension, :type]
    attr_accessor *@attribute_names
    TYPES = ["Cell", "Home", "Work", "Other"]

    def phone_number=(number)
      number_a = number.to_s.split(/x|X/)
      if number_a.size == 2
        @extension = number_a.last.gsub(/[^0-9]/, "").strip
      end
      @phone_number = number_a.first.gsub(/[^0-9]/, "").strip
    end

    def extension=(number)
      @extension = number.gsub(/[^0-9]/, "").strip
    end

  end
end
