require 'chronic_duration'
require 'fileutils'
require 'zlib'

# IO like object, that can be used with any logging class (such as Ruby's native Logger). This object will save its input to a file, and allows:
#
# * Hourly or daily rotation.
# * Compression of rotated files.
# * Removal of old compressed files.
#
# This functionality supplement logging classes, allowing everything related to logging management, to be done within Ruby, without relying on external tools (such as logrotate).
class Evanescent
  # Current path being written to.
  attr_reader :path

  # Rotation policy.
  attr_reader :rotation

  # How long rotated files are kept (in seconds).
  attr_reader :keep

  # Shortcut for: <tt>Logger.new(Evanescent.new(opts))</tt>.
  # Requires logger if needed.
  def self.logger opts
    unless Object.const_defined? :Logger
      require 'logger'
    end
    Logger.new(
      self.new(opts)
    )
  end

  # Must receive a Hash with:
  # +:path+:: Path where to write to.
  # +:rotation+:: Either +:hourly+ or +:daily+.
  # +:keep+:: For how long to keep rotated files. It is parsed with chronic_duration Gem natural language features. Examples: '1 day', '1 month'.
  def initialize opts
    @path = opts[:path]
    @rotation = opts[:rotation]
    @keep = ChronicDuration.parse(opts[:keep])
    @mutex = Mutex.new
    @last_prefix = make_suffix(Time.now)
    @io = nil
    @compress_thread = nil
  end

  # Writes to #path and rotate, compress and purge if necessary.
  def write string
    @mutex.synchronize do
      if new_path = rotation_path
        # All methods here must have exceptions threated. See:
        # https://github.com/ruby/ruby/blob/3e92b635fb5422207b7bbdc924e292e51e21f040/lib/logger.rb#L647
        purge
        mv_path(new_path)
        compress
      end
      open_io
      if @io
        # No exceptions threated here, they should be handled by caller. See:
        # https://github.com/ruby/ruby/blob/3e92b635fb5422207b7bbdc924e292e51e21f040/lib/logger.rb#L653
        @io.write(string)
      else
        warn("Unable to log: '#{path}' not open!")
        0
      end
    end
  end

  # Close file.
  def close
    @mutex.synchronize do
      @io.close
    end
  end

  # Compression is done in a separate thread. This method suspends current thread execution until existing compression thread returns. If no compression thread is running, returns immediately.
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

  def make_suffix time
    time.strftime(PARAMS[rotation][:strftime])
  end

  def open_io
    unless @io
      @io = File.open(path, File::APPEND | File::CREAT | File::WRONLY)
      @io.sync = true
    end
  rescue
    warn("Unable to open '#{path}': #{$!} (#{$!.class})")
  end

  # Returns new path for rotation. If no rotation is needed, returns nil.
  def rotation_path
    if @io
      curr_suffix = make_suffix(Time.now)
      return nil if curr_suffix == @last_prefix
      # Same as https://github.com/ruby/ruby/blob/3e92b635fb5422207b7bbdc924e292e51e21f040/lib/logger.rb#L760
      begin
        @io.close
      rescue
        warn("Error closing '#{path}': #{$!} (#{$!.class})")
      end
      @io = nil
      @last_prefix = curr_suffix
      "#{path}.#{curr_suffix}"
    else
      return nil unless File.exist?(path)
      curr_suffix = make_suffix(Time.now+PARAMS[rotation][:interval])
      rotation_suffix = make_suffix(File.mtime(path) + PARAMS[rotation][:interval])
      return nil if curr_suffix == rotation_suffix
      @last_prefix = curr_suffix
      "#{path}.#{rotation_suffix}"
    end
  end

  def purge
    Dir.glob("#{path}.#{PARAMS[rotation][:glob]}.gz").each do |compressed|
      time_extractor = Regexp.new(
        '^' + Regexp.escape("#{path}.") + "(?<time>.+)" + Regexp.escape(".gz") + '$'
      )
      time_string = compressed.match(time_extractor)[:time]
      compressed_time = Time.strptime(time_string, PARAMS[rotation][:strftime])
      age = Time.now - compressed_time
      if age >= keep
        File.delete(compressed)
      end
    end
  rescue
    warn("Error purging old files: #{$!} (#{$!.class})")
  end

  def mv_path new_path
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
