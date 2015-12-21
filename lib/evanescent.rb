require 'chronic_duration'
require 'fileutils'
require 'zlib'

# IO like object, that can be used with any logging class (such as Ruby's native Logger). This object will save its input to a file, and allows:
#* Rotation by time / date.
#* Compression of old files.
#* Removal of old compressed files.
# Its purpuse is to supplement logging classes, allowing everything related to logging management, to be done within Ruby, without relying on external tools (such as logrotate).
class Evanescent
  # Current path being written to.
  attr_reader :path

  # Rotation policy.
  attr_reader :rotation

  # How long rotated files are kept (in seconds).
  attr_reader :keep

  # Must receive a Hash with:
  # +:path+:: Path where to write to.
  # +:rotation+:: Either +:hourly+ or +:daily+.
  # +:keep+:: For how long to keep rotated files. It is parsed with ChronicDuration's natural language features. Examples: '1 day', '1 month'.
  def initialize opts
    @path = opts[:path]
    @rotation = opts[:rotation]
    @keep = ChronicDuration.parse(opts[:keep])
    @mutex = Mutex.new
    @last_prefix = make_prefix(Time.now)
    @io = nil
    @compress_thread = nil
  end

  # Writes to #path and rotate, compress and purge if necessary.
  def write string
    @mutex.synchronize do
      # All methods here must have exceptions threated, to mimic Logger's default behaviour (https://github.com/ruby/ruby/blob/3e92b635fb5422207b7bbdc924e292e51e21f040/lib/logger.rb#L647)
      purge
      rotate
      compress
      # No exceptions threated here on, as they should be handled by caller (eg: https://github.com/ruby/ruby/blob/3e92b635fb5422207b7bbdc924e292e51e21f040/lib/logger.rb#L653)
      open_io
      @io.write(string)
    end
  end

  # Close file.
  def close
    @mutex.synchronize do
      @io.close
    end
  end

  # Compression is done in a separate thread. Thus method suspends current thread execution until existing compression thread returns. If no compression thread is running, returns immediately.
  def wait_compression
    if @compress_thread
      begin
        @compress_thread.join
      rescue
        warn("Compression thread failed: #{$!} (#{$!.class})")
      ensure
        @compress_thread = nil
      end
    end
  end

  private

  def open_io
    unless @io
      @io = File.open(path, File::APPEND | File::CREAT | File::WRONLY)
      @io.sync = true
    end
  end

  PARAMS = {
    hourly: {
      strftime: '%Y%m%d%H',
      glob: '[0-9]' * (4 + 2 * 3),
      interval: 3600
    },
    daily: {
      strftime: '%Y%m%d',
      glob: '[0-9]' * (4 + 2 * 2),
      interval: 3600 * 24
    }
  }

  def make_prefix time
    time.strftime(PARAMS[rotation][:strftime])
  end

  def purge
    Dir.glob("#{path}.#{PARAMS[rotation][:glob]}.gz").each do |compressed|
      time_extractor = Regexp.new(
        '^' + Regexp.escape("#{path}.") + "(?<time>.+)" + Regexp.escape(".gz") + '$'
      )
      time_string = compressed.match(time_extractor)[:time]
      compressed_time = Time.strptime(time_string, PARAMS[rotation][:strftime])
      age = Time.now - compressed_time
      if age > keep
        File.delete(compressed)
      end
    end
  rescue
    warn("Error purging old files: #{$!} (#{$!.class})")
  end

  def rotate
    if @io
      rotate_with_open_io
    else
      rotate_with_closed_io
    end
  end

  def rotate_with_open_io
    curr_suffix = make_prefix(Time.now)
    return if curr_suffix == @last_prefix
    @io.close rescue nil # Same as https://github.com/ruby/ruby/blob/3e92b635fb5422207b7bbdc924e292e51e21f040/lib/logger.rb#L760
    @io = nil
    do_rotation("#{path}.#{curr_suffix}")
    @last_prefix = curr_suffix
  end

  def rotate_with_closed_io
    return unless File.exist?(path)
    curr_suffix = make_prefix(Time.now+PARAMS[rotation][:interval])
    rotation_suffix = make_prefix(File.mtime(path) + PARAMS[rotation][:interval])
    return if curr_suffix == rotation_suffix
    do_rotation("#{path}.#{rotation_suffix}")
    @last_prefix = curr_suffix
  end

  def do_rotation new_path
    FileUtils.mv(path, new_path)
  rescue
    warn("Error renaming '#{path}' to '#{new_path}': #{$!} (#{$!.class})")
  end

  def compress
    wait_compression
    @compress_thread = Thread.new do
      Dir.glob("#{path}.#{PARAMS[rotation][:glob]}").each do |uncompressed|
        compressed = "#{uncompressed}.gz"
        Zlib::GzipWriter.open(compressed) do |gz|
          gz.mtime = File.mtime(uncompressed)
          gz.orig_name = uncompressed
          File.open(uncompressed, 'r') do |io|
            io.binmode
            io.each do |data|
              gz.write(data)
            end
          end
        end
        File.delete(uncompressed)
      end
    end
  rescue
    warn("Error compressing files: #{$!} (#{$!.class})")
  end

end
