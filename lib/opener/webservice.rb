require "uuidtools"
require "sinatra/base"
require "json"
require "opener/webservice/version"
require "opener/webservice/opt_parser"

module Opener
  class Webservice < Sinatra::Base
    
    configure do
      enable :logging
    end

    configure :development do
      set :raise_errors, true
      set :dump_errors, true
    end

    ##
    # Presents a simple form that can be used for getting the NER of a KAF
    # document.
    #
    get '/' do
      erb :index
    end

    ##
    # Puts the text through the primary processor
    #
    # @param [Hash] params The POST parameters.
    #
    # @option params [String] :input the input to send to the processor
    # @option params [Array<String>] :callbacks A collection of callback URLs
    #  that act as a chain. The results are posted to the first URL which is
    #  then shifted of the list.
    # @option params [String] :error_callback Callback URL to send errors to
    #  when using the asynchronous setup.
    #
    post '/' do
      if !params[:input] or params[:input].strip.empty?
        logger.error('Failed to process the request: no input specified')

        halt(400, 'No input specified')
      end

      callbacks = extract_callbacks(params[:callbacks])
      error_callback = params[:error_callback]

      if callbacks.empty?
        process_sync
      else
        process_async(callbacks, error_callback)
      end
    end

    ##
    # @return [HTTPClient]
    #
    def self.http_client
      return @http_client || new_http_client
    end

    ##
    # @return [HTTPClient]
    #
    def self.new_http_client
      client = HTTPClient.new
      client.connect_timeout = 120

      return client
    end

    ##
    # Specifies the text processor to use or returns it if no parameter is
    # given.
    #
    # @param [Class] processor
    # @return [Class]
    #
    def self.text_processor(processor=nil)
      if processor.nil?
        return @processor
      else
        @processor = processor
      end
    end

    ##
    # Specifies what parameters are accepted.
    #
    # @param [Array] array The parameters to accept.
    #
    def self.accepted_params(*array)
      if array.empty?
        return @accepted_params
      else
        @accepted_params = array
      end
    end

    ##
    # @return [Class]
    #
    def text_processor
      self.class.text_processor
    end

    ##
    # @return [Array]
    #
    def accepted_params
      self.class.accepted_params
    end

    ##
    # Processes the request synchronously.
    #
    def process_sync
      output, type = analyze(filtered_params)
      content_type(type)
      body(output)
    end

    ##
    # Filter the params hash based on the accepted_params
    #
    # @return [Hash] accepted params
    #
    def filtered_params
      options = params.select{|k,v| accepted_params.include?(k.to_sym)}
      cleaned = {}
      options.each_pair do |k, v|
        v = true  if v == "true"
        v = false if v == "false"
        cleaned[k.to_sym] = v
      end

      return cleaned
    end

    ##
    # Processes the request asynchronously.
    #
    # @param [Array] callbacks The callback URLs to use.
    #
    def process_async(callbacks, error_callback)
      request_id = get_request_id
      output_url = callbacks.last
      Thread.new do
        analyze_async(filtered_params, request_id, callbacks, error_callback)
      end

      content_type :json

      {
        :request_id => request_id.to_s,
        :output_url => [output_url, request_id].join("/")
      }.to_json
    end

    ##
    # Gets the Analyzed output of an input.
    #
    # @param [Hash] options The options for the text_processor
    # @return [String] output the output of the text_processor
    # @return [Symbol] type the output type ot the text_processor
    #
    # @raise RunetimeError Raised when the tagging process failed.
    #
    def analyze(options)
      processor             = text_processor.new(options)
      output, error, status = processor.run(options[:input])

      if processor.respond_to?(:output_type)
        type = processor.output_type
      else
        type = :xml
      end

      raise(error) if !status.nil? && !status.success?

      return output, type
    end

    ##
    # Gets the NER of a KAF document and submits it to a callback URL.
    #
    # @param [String] text
    # @param [String] request_id
    # @param [Array] callbacks
    # @param [String] error_callback
    #
    def analyze_async(options, request_id, callbacks, error_callback = nil)
      begin
        output, _ = analyze(options)
      rescue => error
        logger.error("Failed to process input: #{error.inspect}")

        submit_error(error_callback, error.message) if error_callback
      end

      url = callbacks.shift

      logger.info("Submitting results to #{url}")

      begin
        process_callback(url, output, request_id, callbacks, error_callback)
      rescue => error
        logger.error("Failed to submit the results: #{error.inspect}")

        submit_error(error_callback, error.message) if error_callback
      end
    end

    ##
    # @param [String] url
    # @param [String] text
    # @param [String] request_id
    # @param [Array] callbacks
    #
    def process_callback(url, text, request_id, callbacks, error_callback)
      # FIXME: this is a bit of a hack to prevent the webservice from clogging
      # Airbrake during the hackathon. For whatever reason somebody is posting
      # internal server errors from *somewhere*. Validation? What's that?
      return if text =~ /^internal server error/i

      output = {
        :input          => text,
        :request_id     => request_id,
        :'callbacks[]'  => callbacks,
        :error_callback => error_callback
      }

      http_client.post_async(
        url,
        :body => filtered_params.merge(output)
      )
    end

    ##
    # @param [String] url
    # @param [String] message
    #
    def submit_error(url, message)
      http_client.post_async(url, :body => {:error => message})
    end

    ##
    # Returns an Array containing the callback URLs, ignoring empty values.
    #
    # @param [Array|String] input
    # @return [Array]
    #
    def extract_callbacks(input)
      return [] if input.nil? || input.empty?

      callbacks = input.compact.reject(&:empty?)

      return callbacks
    end

    ##
    # @return [String]
    #
    def get_request_id
      return params[:request_id] || UUIDTools::UUID.random_create
    end

    ##
    # @see Opener::Webservice.http_client
    #
    def http_client
      return self.class.http_client
    end
  end
end
