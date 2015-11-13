require 'chronic_duration'

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
    open_file
  end

  # Writes to #path and rotate, compress and purge if necessary.
  def write string
    @mutex.synchronize do
      rotate
      compress
      purge
      @io.write(string)
    end
  end

  # Close file.
  def close
    @mutex.synchronize do
      @io.close
    end
  end

  private

  def open_file
    @io = File.open(path, File::APPEND | File::CREAT | File::WRONLY)
    @io.sync = true
  end

  PARAMS = {
    hourly: {
      strftime: '%Y%m%d%H',
      glob: '[0-9]' * (4 + 2 * 3)
    },
    daily: {
      strftime: '%Y%m%d',
      glob: '[0-9]' * (4 + 2 * 2)
    }
  }

  def make_prefix time
    time.strftime(PARAMS[rotation][:strftime])
  end

  def rotate
    curr_suffix = make_prefix(Time.now)
    if curr_suffix != @last_prefix
      @io.close
      rotated = "#{path}.#{curr_suffix}"
      begin
        FileUtils.mv(path, rotated)
      rescue
        warn("Error renaming '#{path}' to '#{rotated}': #{$!}")
      end
      open_file
      @last_prefix = curr_suffix
    end
  end

  def compress
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
  rescue
    warn("Error compressing files: #{$!}")
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
    warn("Error purging old files: #{$!}")
  end

end
