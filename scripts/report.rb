require 'dogapi'
require 'awesome_print'
require 'active_support'
require 'active_support/core_ext'
require 'action_view'
require 'action_view/helpers'
require 'oj'
require 'hirb'
include ActionView::Helpers::DateHelper

Hirb.enable
Hirb::Formatter.dynamic_config['ActiveRecord::Base']
Hirb::View.resize(300, 300)
module Kernel

  private
  def pp(objs, options={})
    puts Hirb::Helpers::AutoTable.render(objs, options)
  end

  def pretty_json(obj)
    str = obj.is_a?(Hash) ? obj.to_json : obj.to_s
    JSON.pretty_generate(JSON.parse(str))
  end

  module_function :pp, :pretty_json
end

api_key=ENV['DATADOG_API_KEY']
app_key=ENV['DATADOG_APP_KEY']

ENV_ALIASES = {
    "prod" => 'production/us1',
    "qa" => 'qa/deployment',
    "dev" => 'development/us1',
    "eu" => 'production/eu1'
}

environment = ENV['APPLICATION_ENVIRONMENT']
if environment.blank?
  environment = ENV_ALIASES['qa']
end
if ENV_ALIASES.keys.include?(environment.downcase)
  environment = ENV_ALIASES[environment.downcase]
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
          # ap params
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
result = query_service.query(Time.now-10.minutes, Time.now-1.minutes, "max:pulse.application.monitor{environment:#{environment}} by {#{tags.join(',')}}").last.deep_symbolize_keys
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

def group_by_tags(raw_metrics_data, *tags_to_group_by)
  root_node = {} # the result tree, as a nested hash
  raw_metrics_data.each { |metric_data|
    metric = metric_data.dup # duplicate, because we're going to mutate the data
    current_node = root_node
    tags_to_group_by.each { |datadog_tag|
      tag_value = metric.delete(datadog_tag)
      unless current_node.has_key?(tag_value)
        current_node[tag_value] = {}
      end
      current_node = current_node[tag_value]
    }
    metric.each { |k, v|
      current_node[k]=v
    }
  }
  root_node
end

report_data = group_by_tags(metrics, :environment, :git_repo, :host, :instance_name)

report_rows = []
rows_by_app = {}
report_data.each { |environment, env_data|
  env_data.each { |app_name, app_data|
    app_rows = []
    app_data.each { |host, host_data|
      host_data.each { |instance_name, instance_data|
        app_rows << {
            env: environment,
            app: app_name,
            host: host,
            instance: instance_name
        }.merge(instance_data)
      }
    }
    rows_by_app[app_name] = app_rows
    report_rows += app_rows
  }
}

version_rows = []

rows_by_app.each { |app_name, app_rows|
  rows_by_last_commit = app_rows.group_by { |r| r[:last_commit] }
  rows_by_last_commit.each { |last_commit, rows|
    rows_by_host = rows.group_by { |r| r[:host] }
    host_counts = {}
    rows_by_host.each { |host, instances|
      host_counts[host] = instances.size
    }
    shared_info = rows[0]
    t = Time.parse(shared_info[:last_commit_time]).in_time_zone(Time.zone)
    ts_label= t.strftime("%_m/%d/%Y %l:%M %p")   #=> "Printed on 11/19/2007"
    time_ago = distance_of_time_in_words(t, Time.now, include_seconds: false)
    t.strftime("at %I:%M%p")
    app_meta = {
        app: app_name,
        hosts: host_counts.keys.sort,
        instance_count: rows.size,
        host_instance_counts: host_counts.sort.to_h.map{|k,v| "#{k} => #{v}"}.join(', '),
        env: shared_info[:env],
        git_branch: shared_info[:git_branch],
        git_tag: shared_info[:git_tag],
        last_commit: last_commit,
        last_commit_time: "#{ts_label} (#{time_ago} ago)"
    }
    version_rows << app_meta
  }
}
puts "Big Brother Report for environment '#{environment}':\n\n"
pp version_rows.sort_by { |r| r[:app] }, {fields: [:app, :last_commit, :last_commit_time, :git_branch, :git_tag, :instance_count, :hosts, :host_instance_counts]}
exit 0