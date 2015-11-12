require 'evanescent'
require 'tmpdir'
require 'fileutils'
require 'tempfile'

RSpec.describe Evanescent do
  let(:prefix) { Dir.mktmpdir }
  let(:log_file) { Tempfile.new('log', prefix).path }
  after(:example) do
    FileUtils.rm_rf(prefix)
  end
  let(:data) { 'oeutaohuaorl891237412' }
  let(:evanescent) do
    described_class.new(
      path: log_file,
    )
  end
  it 'writes to file' do
    times = 3
    times.times do
      evanescent.io.write(data)
    end
    evanescent.close
    expect(File.open(log_file).read).to eq(data*times)
  end
end
