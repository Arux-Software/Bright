class CursorResponseCollection < ResponseCollection

  attr_accessor :collected_objects

  def initialize(options = {})
    @collected_objects = [options[:seed_page]].flatten
    @per_page = options[:per_page].to_i
    @load_more_call = options[:load_more_call]
    @next_cursor = options[:next_cursor]
  end

  def each
    while (!@next_cursor.blank?) do
      objects_hsh = load_more_call.call(@next_cursor)
      objects = objects_hsh[:objects]
      @next_cursor = objects_hsh[:next_cursor]
      objects.each do |obj|
        yield obj
      end
      @collected_objects += objects
    end
  end

  def last
    self.to_a
    return @collected_objects.last
  end

  def loaded_results
    @collected_objects.flatten
  end

  def total
    self.to_a
    self.loaded_results.size
  end

  alias size total
  alias length total

  def empty?
    self.to_a.empty?
  end

end
