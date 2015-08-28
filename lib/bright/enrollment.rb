module Bright
  class Enrollment < Model
    @attribute_names = [:student, :school, :entry_date, :entry_comment, :exit_date, :exit_comment, :grade]
    attr_accessor *@attribute_names
  end
end