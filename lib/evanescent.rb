class Evanescent
  def initialize opts
    @read_io, @write_io = IO.pipe
    @file_io = File.open(opts[:path], 'w+')
    @thread = Thread.new { sender_thread }
  end
  def io
    @write_io
  end
  def close
    @write_io.close
    @thread.join
    @file_io.close
  end
  private
  def sender_thread
    @read_io.each do |data|
      @file_io.write(data)
    end
  end
end
