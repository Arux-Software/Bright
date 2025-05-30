require "parallel"

class ResponseCollection
  include Enumerable

  attr_accessor :paged_objects
  attr_accessor :total
  attr_accessor :per_page
  attr_accessor :load_more_call

  DEFAULT_NO_THREADS = 4

  # seed_page, total, per_page, load_more_call
  def initialize(options = {})
    @paged_objects = {0 => options[:seed_page]}
    @total = options[:total].to_i
    @per_page = options[:per_page].to_i
    @pages = (@per_page > 0) ? (@total.to_f / @per_page.to_f).ceil : 0
    @load_more_call = options[:load_more_call]
    @no_threads = options[:no_threads] || DEFAULT_NO_THREADS
  end

  def each
    Parallel.each(0..@pages, in_threads: @no_threads) do |current_page|
      objects = if @paged_objects[current_page].present?
        @paged_objects[current_page]
      else
        load_more_call.call(current_page)
      end
      objects = [objects].flatten.compact
      @paged_objects[current_page] = objects if objects.present?
      objects.each do |obj|
        yield obj
      end
    end
  end

  def last
    last_page_no = @pages - 1
    if load_more_call and (last_page = @paged_objects[last_page_no]).nil?
      last_page = @paged_objects[last_page_no] = load_more_call.call(last_page_no)
    end
    last_page.last
  end

  def loaded_results
    @paged_objects.values.flatten
  end

  alias_method :size, :total
  alias_method :length, :total

  def empty?
    total <= 0
  end
end
