class FalseClass
  def blank?
    true
  end
end

class TrueClass
  def blank?
    false
  end
end

class Object
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end
end
