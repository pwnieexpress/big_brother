require 'dogapi'
require 'awesome_print'
require 'active_support'
require 'active_support/core_ext'
require 'oj'

api_key=ENV['DATADOG_API_KEY']
app_key=ENV['DATADOG_APP_KEY']

environment = ENV['APPLICATION_ENVIRONMENT']
if environment.blank?
  environment='qa/deployment'
end

module Dogapi
  class V1 # for namespacing

    # Event-specific client affording more granular control than the simple Dogapi::Client
    class QueryService < Dogapi::APIService

      API_VERSION = "v1"

      def query(from, to, q)
        begin
          params = {
              :api_key => @api_key,
              :application_key => @application_key,
              :from => from.to_i,
              :to => to.to_i,
              :query => q
          }
          ap params
          request(Net::HTTP::Get, '/api/' + API_VERSION + '/query', params, nil, false)
        rescue Exception => e
          if @silent
            warn e
            return -1, {}
          else
            raise e
          end
        end
      end
    end
  end
end

query_service = Dogapi::V1::QueryService.new(api_key, app_key, true, nil)
tags = [
    :host,
    :instance_name,
    :git_repo,
    :last_commit,
    :last_commit_time,
    :git_branch,
    :git_tag
]
result = query_service.query(Time.now-10.minutes, Time.now-5.minutes, "max:pulse.application.monitor{environment:#{environment}} by {#{tags.join(',')}}").last.deep_symbolize_keys
if result[:error]
  puts result[:error]
  exit 1
else
  data = result[:series]
end

metrics = data.map { |datum|
  Hash[datum[:scope].split(',').map { |tag|
    parts = tag.partition(':')
    [parts.first.to_sym, parts.last]
  }]
}

def group_by_tags(data, *tags_to_group_by)
  result = {}
  data.each { |metric|
    current_branch = result
    m = metric.dup
    tags_to_group_by.each { |group_by_tag|
      value = m.delete(group_by_tag)
      unless current_branch.has_key?(value)
        current_branch[value] = {}
      end
      current_branch = current_branch[value]
    }
    m.each { |k, v|
      current_branch[k]=v
    }
  }
  result
end

puts "Big Brother Reports:"
ap group_by_tags(metrics, :environment, :git_repo, :host, :instance_name)
exit 0