module Bright
  class Enrollment < Model
    attr_accessor :student, :school, :entry_date, :entry_comment, :exit_date, :exit_comment, :grade
  end
end