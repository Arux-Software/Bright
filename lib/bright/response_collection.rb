class ResponseCollection
  include Enumerable
  
  attr_accessor :paged_objects
  attr_accessor :total
  attr_accessor :per_page
  attr_accessor :load_more_call
  
  # seed_page, total, per_page, load_more_call
  def initialize(options = {})
    @paged_objects = {0 => options[:seed_page]}
    @total = options[:total].to_i
    @per_page = options[:per_page].to_i
    @pages = @per_page > 0 ? (@total.to_f / @per_page.to_f).ceil : 0
    @load_more_call = options[:load_more_call]
  end
  
  def each
    current_page = -1
    while (current_page += 1) < @pages do
      objects = [@paged_objects[current_page]].flatten.compact
      next_page_no = current_page + 1
      if load_more_call and @paged_objects[next_page_no].nil? and next_page_no < @pages
        next_page_thread = Thread.new do
          load_more_call.call(next_page_no)
        end
      else
        next_page_thread = nil
      end
      objects.each do |obj|
        yield obj
      end
      @paged_objects[next_page_no] = next_page_thread.value if next_page_thread
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
  
  alias size total
  alias length total

  def empty?
    total <= 0
  end
end