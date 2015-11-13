require 'evanescent'
require 'tmpdir'
require 'fileutils'
require 'tempfile'
require 'timecop'

RSpec.describe Evanescent do
  let(:prefix) { Dir.mktmpdir }
  let(:path) { Tempfile.new('log', prefix).path }
  after(:example) do
    FileUtils.rm_rf(prefix)
  end
  let(:data) do
    d = []
    10.times do |t|
      d << "time\##{t}\n"
    end
    d
  end
  context 'rotation' do
    def cat path
      File.open(path, 'r').read
    end
    def zcat path
      Zlib::GzipReader.open(path) do |gz|
        gz.read
      end
    end
    shared_examples :rotation do
      it 'rotates and compresses' do
        Timecop.freeze(start_time)
        evanescent.write(data_a = data.shift)
        Timecop.freeze(start_time+interval/2)
        evanescent.write(data_b = data.shift)
        first_data = data_a + data_b
        expect(cat(path)).to eq(first_data)

        Timecop.freeze(start_time + interval)
        evanescent.write(data_a = data.shift)
        Timecop.freeze(start_time + interval + interval/2)
        evanescent.write(data_b = data.shift)
        second_data = data_a + data_b
        expect(cat(path)).to eq(second_data)
        expect(zcat("#{path}.#{sufixes.shift}.gz")).to eq(first_data)

        Timecop.freeze(start_time + interval*2)
        evanescent.write(data_a = data.shift)
        Timecop.freeze(start_time + interval*2 + interval/2)
        evanescent.write(data_b = data.shift)
        third_data = data_a + data_b
        expect(cat(path)).to eq(third_data)
        expect(zcat("#{path}.#{sufixes.shift}.gz")).to eq(second_data)

        files_count = Dir.glob("#{prefix}/*").size
        expect(files_count).to eq(2)
      end
    end
    let(:tz) { Time.now.strftime('%z') }
    context 'hourly' do
      let(:evanescent) do
        described_class.new(
          path: path,
          rotation: :hourly,
          keep: '1 hour',
        )
      end
      let(:interval) { 3600 }
      let(:start_time) { Time.parse("2015-11-03 00:00:00 #{tz}") }
      let(:sufixes) do
        [
          '2015110301',
          '2015110302',
        ]
      end
      include_examples :rotation
    end
    context 'daily' do
      let(:evanescent) do
        described_class.new(
          path: path,
          rotation: :daily,
          keep: '1 day',
        )
      end
      let(:interval) { 3600*24 }
      let(:start_time) { Time.parse("2015-11-03 00:00:00 #{tz}") }
      let(:sufixes) do
        [
          '20151104',
          '20151105',
        ]
      end
      include_examples :rotation
    end
  end
end
