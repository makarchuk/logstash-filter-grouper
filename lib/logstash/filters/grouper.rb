require "logstash/filters/base"
require "logstash/namespace"
require "base64"


# Search Elasticsearch index for records that match some field in event
# create new one or update existing depending on was record found or not. 
# Can be used to aggregate events on some field.


class LogStash::Filters::Grouper < LogStash::Filters::Base
  config_name "grouper"

  # List of elasticsearch hosts to use for querying.
  config :hosts, :validate => :array

  # Elasticsearch query string
  config :match_field, :validate => :string

  # Hash of fields to copy from old event (found via elasticsearch) into new event
  config :fields, :validate => :hash, :default => {}

  # Basic Auth - username
  config :user, :validate => :string

  # Basic Auth - password
  config :password, :validate => :password

  # SSL
  config :ssl, :validate => :boolean, :default => false

  # SSL Certificate Authority file
  config :ca_file, :validate => :path

  # Fields to copy to new document
  # key -- source field, value -- result field
  # If value is empty result field = source_field
  config :only_fields, :validate => :hash, :default => {}

  # Fields that will be excluded from result document. Don't work if :only_fields is set
  config :exclude, :validate => :array, :default => []
  
  # Fields that will be stored as array in result document
  config :to_array, :validate => :array, :default => []

  # Hash of fields that needs to be incremented
  # Key -- field in result documtn 
  # Value -- field in event or number
  config :sum_fields, :validate => :hash, :default => {}
  
  config :inherit_fields, :validate => :array, :default => []

  # Add fields. Executes BEFORE filter executing
  config :add_fields, :falidate =>:hash, :default => {}

  config :remove_field, :falidate =>:array, :default => []

  config :doc_index, :validate => :string

  config :doc_type, :validate => :string

  public
  def register
    require "elasticsearch"

    transport_options = {}

    if @user && @password
      token = Base64.strict_encode64("#{@user}:#{@password.value}")
      transport_options[:headers] = { Authorization: "Basic #{token}" }
    end

    hosts = if @ssl then
      @hosts.map {|h| { host: h, scheme: 'https' } }
    else
      @hosts
    end

    if @ssl && @ca_file
      transport_options[:ssl] = { ca_file: @ca_file }
    end

    @logger.info("New ElasticSearch filter", :hosts => hosts)
    @my_little_logger = Logger.new "/var/log/logstash/my_filter.log"
    @client = Elasticsearch::Client.new hosts: hosts, transport_options: transport_options
  end # def register

  public
  def filter(event)
    return unless filter?(event)
    begin
      id = event[@match_field]

      @add_fields.each do |k, v|
        event[k] = v if event[k].nil?
      end
      
      if only_fields.count > 0
        grouped_event = LogStash::Event.new {}
        grouped_event.cancel
        @only_fields.each do |k, v|
          v = k if v.strip.empty?
          grouped_event[v] = event[k]
        end
      else
        grouped_event = event.clone
        grouped_event.cancel
        @exclude.each do |f| 
          grouped_event.remove f
        end
      end

      @to_array.each do |k|
        grouped_event[k] = [event[k]]
      end

      @sum_fields.each do |k, v|
        if v.kind_of? Numeric
          grouped_event[k] = v
        else
          grouped_event[k] = event[v]
        end
      end
      script = ""
      @sum_fields.each do |k, v|
        if v.kind_of? Numeric
          script << "ctx._source['#{k}']+=#{v}; "
        else
          script << "ctx._source['#{k}'] += '#{grouped_event[v]}'; "
        end
      end
      @to_array.each do |field|
        script << "ctx._source['#{field}'] += '#{grouped_event[field][0]}'; "  
      end
      @client.update index: @doc_index, type: @doc_type, body: {script: script, upsert: grouped_event.to_hash}, consistency: "all", id: id, lang: "python", retry_on_conflict: 5
      record = @client.get index: @doc_index, type: @doc_type, id: id
      @inherit_fields.each do |f| 
        event[f] = record[f] if record.has_key? f
      end
      @remove_field.each do |field|
        event.remove(field)
      end
    rescue => e
      @my_little_logger.error e
      @my_little_logger.error e.message
      @my_little_logger.error e.backtrace
    end
  end # def filter
end # class LogStash::Filters::Elasticsearch
