require 'statsd-instrument'
require 'socket'

# Define the 'blank?' method if it doesn't exist
unless Object.method_defined? :blank?
  class Object
    def blank?
      if respond_to?(:empty?)
        empty?
      else
        !self
      end
    end
  end
end

# A simple asynchronous metrics service that publishes information about the running application to datadog. The metrics
# collected here are to help us verify what version of the code is running where, and catch if we have any discrepancies.
class BigBrother
  PULSE_APPLICATION_MONITOR_METRIC_NAME = 'pulse.application.monitor'.freeze

  class NullLogger < BasicObject
    def method_missing(*args, &block)
      self
    end
  end

  def initialize
    @stopped = false
    @last_polled = nil
    @last_reported_metrics = nil
    @polling_interval_in_seconds = 5*60
    if ENV['BIG_BROTHER_WATCH_INTERVAL']
      custom_polling_interval = ENV['BIG_BROTHER_WATCH_INTERVAL'].to_i rescue 5*60
      if custom_polling_interval >= 1
        @polling_interval_in_seconds = custom_polling_interval
      end
    end
    @metric_name = ENV['PULSE_APPLICATION_MONITOR_METRIC'] || PULSE_APPLICATION_MONITOR_METRIC_NAME
  end

  def git_repo
    @git_repo ||= begin
      remote_repo = `git remote -v | head -n 1`.strip
      m = /.*\/(.*)\.git.*/.match(remote_repo)
      m[1].blank? ? 'unknown' : m[1]
    end rescue 'unknown'
  end

  def last_commit
    @last_commit ||= `git rev-parse HEAD`.strip rescue 'unknown'
  end

  def last_commit_time
    @last_commit_time ||= `git log -1 --format=format:%ai`.strip rescue 'unknown'
  end

  def git_branch
    @git_branch ||= begin
      refs = `git show-ref --heads`.strip.split("\n").map { |str| str.split(' ') }
      last_ref = refs.find { |parts| parts[0] == last_commit }
      if last_ref.blank?
        "none"
      else
        last_ref.last.gsub("refs/heads/", "")
      end
    end rescue 'unknown'
  end

  def git_tag
    @git_tag ||= begin
      git_tags = `git tag --points-at HEAD`.strip
      git_tags.blank? ? 'none' : git_tags.split("\n").last
    end rescue 'unknown'
  end

  def tags
    {
        instance_name: instance_name,
        ip_address: ip_address,
        server: server,
        git_repo: git_repo,
        last_commit: last_commit,
        last_commit_time: last_commit_time,
        git_branch: git_branch,
        git_tag: git_tag
    }
  end

  def server
    @server ||= Resolv.getname(ENV['CONSUL_ADDR']) rescue 'unknown'
  end

  def ip_address
    @ip_address ||= ENV['CONSUL_ADDR'] || Socket.ip_address_list.detect { |intf| intf.ipv4_private? }.ip_address rescue 'unknown'
  end

  def instance_name
    @instance_name ||= ENV['HOSTNAME'].blank? ? "#{Socket.gethostname}" : ENV['HOSTNAME'] rescue 'unknown'
  end

  def last_polled_at
    @last_polled
  end

  def last_reported_data
    @last_reported_data
  end

  def polling_interval_in_seconds
    @polling_interval_in_seconds
  end

  def poll
    return if stopped?
    datadog_tags = Array(tags).map{|tag| tag.join(':')}
    StatsD.gauge(@metric_name, 1, {sample_rate: 1.0, tags: datadog_tags})
    puts "[Big Brother] Reported application metrics via StatsD. Waiting #{polling_interval_in_seconds} seconds to report again."
    @last_polled = Time.now
    @last_reported_data = {metric: @metric_name, tags: @tags}
    sleep(polling_interval_in_seconds)
    poll
  end

  def stop
    @stopped = true
  end

  def stopped?
    @stopped
  end

  def setup_statsd
    unless StatsD.backend && StatsD.backend.is_a?(StatsD::Instrument::Backends::UDPBackend) && StatsD.backend.tags_supported?
      statsd_addr = ENV['STATSD_ADDR'] || '127.0.0.1:8125'
      StatsD.backend = StatsD::Instrument::Backends::UDPBackend.new(statsd_addr, :datadog)
      StatsD.logger = NullLogger.new
    end
  end

  def self.start_watching
    @instance = BigBrother.new
    Thread.start {
      begin
        @instance.setup_statsd
        puts "[Big Brother] Starting application monitor..."
        puts "[Big Brother] Application monitor initialized with a polling interval of #{@instance.polling_interval_in_seconds} seconds and the following application tags: #{@instance.tags.inspect}"
        @instance.poll
      rescue => exception
        puts exception.message
        puts exception.backtrace
        raise exception
      end
    }
  end

  def self.watching?
    @instance && !@instance.stopped?
  end

  def self.last_polled_at
    @instance ? @instance.last_polled_at : nil
  end

  def self.last_reported_data
    @instance ? @instance.last_reported_data : nil
  end

  def self.stop_watching
    @instance.stop
  end
end

