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
  context '::logger' do
    shared_examples :logger do
      subject do
        described_class.logger(
          path: path,
          rotation: :hourly,
          keep: '1 hour',
        )
      end
      let(:message) { data.shift }
      it 'returns Logger instance' do
        expect(subject).to be_a(Logger)
        subject.info message
        contents = File.open(path, 'r').read
        expect(contents).to include(message)
        expect(contents).not_to eq(message)
      end
    end
    context 'logger not required' do
      # "unrequire" logger
      before(:example) do
        $LOADED_FEATURES.delete_if do |path|
          path.match(/\/logger\.rb$/)
        end
        Object.send(:remove_const, :Logger) if Object.const_defined? :Logger
      end
      include_examples :logger
    end
    context 'logger already required' do
      before(:example) do
        require 'logger'
      end
      include_examples :logger
    end
  end
  context 'rotation' do
    before(:example) do
      Timecop.freeze(start_time)
      expect(evanescent).not_to receive(:warn)
    end
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
    context 'new file' do
      shared_examples :regular_rotation do
        let(:first_gzip) { "#{path}.#{time_suffixes[0]}.gz" }
        let(:second_gzip) { "#{path}.#{time_suffixes[1]}.gz" }
        it 'does not rotate within first period' do
          evanescent.write(first_write = data.shift)
          Timecop.freeze(start_time+interval/2)
          evanescent.write(second_write = data.shift)
          all_writes = first_write + second_write
          evanescent.wait_compression
          expect(cat(path)).to eq(all_writes)
          files_count = Dir.glob("#{prefix}/*").size
          expect(files_count).to eq(1)
        end
        it 'rotates after first period' do
          evanescent.write(rotated_write = data.shift)
          Timecop.freeze(Time.now + interval)
          evanescent.write(non_rotated_write = data.shift)
          evanescent.wait_compression
          expect(cat(path)).to eq(non_rotated_write)
          expect(zcat(first_gzip)).to eq(rotated_write)
          files_count = Dir.glob("#{prefix}/*").size
          expect(files_count).to eq(2)
        end
        it 'purges after "keep" limit' do
          evanescent.write(data.shift)
          evanescent.wait_compression
          Timecop.freeze(Time.now + interval)
          evanescent.write(compressed_write = data.shift)
          evanescent.wait_compression
          Timecop.freeze(Time.now + interval)
          evanescent.write(uncompressed_write = data.shift)
          evanescent.wait_compression
          expect(cat(path)).to eq(uncompressed_write)
          expect(zcat(second_gzip)).to eq(compressed_write)
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
        let(:time_suffixes) do
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
        let(:time_suffixes) do
          [
            '20151104',
            '20151105',
          ]
        end
        include_examples :regular_rotation
      end
    end
  end
  context 'failures' do
    context '#write' do
      subject do
        described_class.new(
          path: path,
          rotation: :hourly,
          keep: '1 hour',
        )
      end
      let(:uncompressed_path) { path + '.2015122312' }
      let(:compressed_path) { "#{uncompressed_path}.gz" }
      let(:interval) { 3600 }
      context '#purge' do
        shared_examples :purge_not_to_raise do
          it 'does not raise' do
            expect(subject).to receive(:warn).with(String)
            expect do
              subject.send(:purge)
            end.not_to raise_error
          end
        end
        context 'listing failure' do
          before(:example) do
            expect(Dir).to receive(:glob).and_raise(StandardError)
          end
          include_examples :purge_not_to_raise
        end
        context 'deletion failure' do
          before(:example) do
            Timecop.freeze(Time.now)
            subject.write('1')
            subject.wait_compression
            Timecop.freeze(Time.now + interval)
            subject.write('2')
            subject.wait_compression
            Timecop.freeze(Time.now + interval)
            expect(File).to receive(:delete).and_raise(StandardError)
          end
          include_examples :purge_not_to_raise
        end
      end
      context '#rotate' do
        before(:example) do
          Timecop.freeze(Time.now)
          subject.write('1')
          Timecop.freeze(Time.now + interval)
          expect(subject).to receive(:warn).with(String)
        end
        shared_examples :not_to_raise do
          it 'does not raise' do
            expect do
              subject.write('2')
            end.not_to raise_error
          end
        end
        context 'closing failure' do
          before(:example) do
            expect(subject.instance_variable_get(:@io))
              .to receive(:close)
              .and_raise(StandardError)
          end
          include_examples :not_to_raise
        end
        context 'rename failure' do
          before(:example) do
            expect(FileUtils)
            .to receive(:mv)
            .and_raise(StandardError)
          end
          include_examples :not_to_raise
        end
      end
      context '#compress' do
        before(:example) do
          expect(subject).to receive(:warn).with(String)
        end
        context 'listing failure' do
          it 'does not raise' do
            Timecop.freeze(Time.now)
            subject.write('1')
            subject.wait_compression
            Timecop.freeze(Time.now + interval)
            subject.write('2')
            subject.wait_compression
            Timecop.freeze(Time.now + interval)
            expect(Dir).to receive(:glob).and_raise(StandardError)
            expect do
              subject.send(:compress)
              subject.wait_compression
            end.not_to raise_error
          end
        end
        context 'compression failure' do
          it 'does not raise' do
            FileUtils.touch uncompressed_path
            expect(Zlib::GzipWriter)
              .to receive(:open).with(compressed_path).and_raise(StandardError)
            expect(File).not_to receive(:delete)
            expect do
              subject.send(:compress)
              subject.wait_compression
            end.not_to raise_error
          end
        end
        context 'deletion failure' do
          it 'does not raise' do
            FileUtils.touch uncompressed_path
            expect(File)
              .to receive(:delete)
              .with(uncompressed_path).and_raise(StandardError)
            expect do
              subject.send(:compress)
              subject.wait_compression
            end.not_to raise_error
          end
        end
      end
    end
  end
end
