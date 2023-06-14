require_relative "one_roster"

module Bright
  module SisApi
    class OneRoster::InfiniteCampus < OneRoster

      def convert_to_user_data(user_params, bright_type: "Student")
        user_data_hsh = super

        unless user_params["userMasterIdentifier"].blank?
          user_data_hsh[:state_student_id] = user_params["userMasterIdentifier"]
        end

        user_data_hsh
      end

    end
  end
end
