require 'rspec'
require_relative '../lib/big_brother'

describe BigBrother do
  describe '#start_watching' do
    it 'starts watching when invoked and stops watching when told to' do
      start = Time.now
      BigBrother.start_watching
      sleep(1)
      expect(BigBrother.watching?).to be true
      expect(BigBrother.last_polled_at).to be > start
      expect(BigBrother.last_reported_data).to_not be_nil
      BigBrother.stop_watching
      expect(BigBrother.watching?).to be false
    end
  end
end