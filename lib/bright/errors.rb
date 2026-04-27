module Bright
  class ResponseError < StandardError
    attr_reader :response
    attr_reader :uri

    def initialize(response, uri = nil)
      @response = response
      @uri = uri
    end

    def to_s
      "Failed with #{response.code} #{response.message if response.respond_to?(:message)}".strip
    end

    def body
      response.body
    end

    def retryable_error?
      response_code = response&.code.to_i

      return true if (500..599).include?(response_code)
      return true if 408 == response_code

      false
    end
  end

  class UnknownAttributeError < NoMethodError
    attr_reader :record, :attribute

    def initialize(record, attribute)
      @record = record
      @attribute = attribute
      super("unknown attribute '#{attribute}' for #{@record.class}.")
    end
  end
end
