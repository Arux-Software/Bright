module Bright
  class Enrollment < Model
    @attribute_names = [:entry_date, :entry_comment, :exit_date, :exit_comment, :grade]
    attr_accessor *@attribute_names
    attr_accessor :student, :school
  end
end