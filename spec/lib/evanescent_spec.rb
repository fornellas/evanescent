require 'evanescent'
require 'tmpdir'
require 'fileutils'
require 'tempfile'
require 'timecop'

RSpec.describe Evanescent do
  let(:prefix) { Dir.mktmpdir }
  let(:path) { "#{prefix}/file" }
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
    let(:tz) { Time.now.strftime('%z') }
    context 'pre-existing file' do
      let(:evanescent) do
        described_class.new(
          path: path,
          rotation: :hourly,
          keep: '1 hour',
        )
      end
      let(:interval) { 3600 }
      let(:start_time) { Time.parse("2015-11-03 00:00:00 #{tz}") }
      context 'within same window' do
        it 'does not rotate' do
          Timecop.freeze(start_time+interval/2)
          allow(File).to receive(:mtime).and_call_original
          expect(File).to receive(:mtime).with(path).and_return(start_time)
          FileUtils.touch(path)
          evanescent.write(sent_data = data.shift)
          evanescent.wait_compression
          expect(cat(path)).to eq(sent_data)
          files_count = Dir.glob("#{prefix}/*").size
          expect(files_count).to eq(1)
        end
      end
      shared_examples :old_file_rotation do
        let(:suffix) { '2015110300' }
        it 'rotates' do
          previous_data = data.shift
          File.open(path, 'w') do |io|
            io.write previous_data
          end
          Timecop.freeze(now)
          allow(File).to receive(:mtime).and_call_original
          expect(File).to receive(:mtime).with(path).and_return(start_time - interval)
          evanescent.write(new_data = data.shift)
          evanescent.wait_compression
          expect(cat(path)).to eq(new_data)
          expect(zcat("#{path}.#{suffix}.gz")).to eq(previous_data)
        end
      end
      context 'on next window' do
        let(:now) { start_time+interval/2 }
        include_examples :old_file_rotation
      end
      context 'after next window' do
        let(:now) { start_time+interval }
        include_examples :old_file_rotation
      end
    end
    shared_examples :regular_rotation do
      it 'rotates and compresses' do
        Timecop.freeze(start_time)
        evanescent.write(data_a = data.shift)
        Timecop.freeze(start_time+interval/2)
        evanescent.write(data_b = data.shift)
        first_data = data_a + data_b
        evanescent.wait_compression
        expect(cat(path)).to eq(first_data)
        Timecop.freeze(start_time + interval)
        evanescent.write(data_a = data.shift)
        Timecop.freeze(start_time + interval + interval/2)
        evanescent.write(data_b = data.shift)
        second_data = data_a + data_b
        evanescent.wait_compression
        expect(cat(path)).to eq(second_data)
        expect(zcat("#{path}.#{sufixes.shift}.gz")).to eq(first_data)
        Timecop.freeze(start_time + interval*2)
        evanescent.write(data_a = data.shift)
        Timecop.freeze(start_time + interval*2 + interval/2)
        evanescent.write(data_b = data.shift)
        third_data = data_a + data_b
        evanescent.wait_compression
        expect(cat(path)).to eq(third_data)
        expect(zcat("#{path}.#{sufixes.shift}.gz")).to eq(second_data)

        files_count = Dir.glob("#{prefix}/*").size
        expect(files_count).to eq(2)
      end
    end
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
      include_examples :regular_rotation
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
      include_examples :regular_rotation
    end
  end
end
