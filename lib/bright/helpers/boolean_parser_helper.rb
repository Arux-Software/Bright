module Kernel
  def Boolean(string)
    return true if string == true || string =~ /^true$/i || string == "1" || string == 1 || string.to_s.downcase == "yes"
    return false if string == false || string.nil? || string =~ /^false$/i || string == "0" || string == 0 || string.to_s.downcase == "no" || string.blank?
    raise ArgumentError.new("invalid value for Boolean: \"#{string}\"")
  end
end

class Object
  def to_bool
    Boolean(self)
  end
end
