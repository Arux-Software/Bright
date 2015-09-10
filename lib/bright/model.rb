module Bright
  class Model
    @attribute_names = []
    
    def initialize(attributes={})
      assign_attributes(attributes) if attributes

      super()
    end
    
    def assign_attributes(new_attributes)
      if !new_attributes.is_a?(Hash)
        raise ArgumentError, "When assigning attributes, you must pass a hash as an argument."
      end
      return if new_attributes.empty?

      attributes = Hash[new_attributes.collect{|k,v| [k.to_sym, v]}]
      _assign_attributes(attributes)
    end
    
    def self.attribute_names
      @attribute_names
    end
    
    def to_json
      Hash[self.class.attribute_names.collect do |n|
        [n, self.send(n)]
      end].to_json
    end
    
    private

    def _assign_attributes(attributes)
      attributes.each do |k, v|
        _assign_attribute(k, v)
      end
    end

    def _assign_attribute(k, v)
      if respond_to?("#{k}=")
        public_send("#{k}=", v)
      else
        raise UnknownAttributeError.new(self, k)
      end
    end
  end
end