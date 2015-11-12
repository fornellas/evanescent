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
  context '#initialize' do
    it 'does something' do
      described_class.new(
        path: log_file,
      )
    end
  end
end
