module Bright
  module SisApi
    class Base

      def filter_students_by_params(students, params)
        total = params[:limit]
        count = 0
        found = []

        keys = (Student.attribute_names & params.keys.collect(&:to_sym))
        puts "filtering on #{keys.join(",")}"
        students.each do |student|
          break if total and count >= total

          should = (keys).all? do |m|
            student.send(m) =~ Regexp.new(Regexp.escape(params[m]), Regexp::IGNORECASE)
          end
          count += 1 if total and should
          found << student if should
        end
        found
      end

      def connection_retry_wrapper(&block)
        retry_attempts = connection_options[:retry_attempts] || 2
        retries = 0
        begin
          yield
        rescue Bright::ResponseError => e
          retries += 1
          if e.server_error? && retries <= retry_attempts.to_i
            puts "retrying #{retries}: #{e.class.to_s} - #{e.to_s}"
            sleep(retries * 3)
            retry
          else
            raise
          end
        rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Net::ReadTimeout, Net::OpenTimeout, SocketError, EOFError => e
          retries += 1
          if retries <= retry_attempts.to_i
            puts "retrying #{retries}: #{e.class.to_s} - #{e.to_s}"
            sleep(retries * 3)
            retry
          else
            raise
          end
        end
      end

    end
  end
end
