module Opener
  module Webservice
    ##
    # The meat of the webservices: the actual Sinatra application. Components
    # should extend this class and configure it (e.g. to specify what component
    # class to use).
    #
    class Server < Sinatra::Base
      ##
      # List of fields that can contain input to process.
      #
      # @return [Array]
      #
      INPUT_FIELDS = %w{input input_url}

      ##
      # Sets the accepted component parameters. Parameter names are always
      # stored as symbols.
      #
      # @param [Array] params
      #
      def self.accepted_params=(params)
        @accepted_params = params.map(&:to_sym)
      end

      ##
      # Returns the accepted component parameters.
      #
      # @return [Array]
      #
      def self.accepted_params
        return @accepted_params ||= []
      end

      ##
      # Sets the text processor to use.
      #
      # @param [Class] processor
      #
      def self.text_processor=(processor)
        @text_processor = processor
      end

      ##
      # Returns the text processor to use.
      #
      # @return [Class]
      #
      def self.text_processor
        return @text_processor
      end

      configure :production do
        set :raise_errors, false
        set :dump_errors, false
      end

      error do
        Rollbar.report_exception(env['sinatra.error'])

        halt(
          500,
          'An error occurred. A team of garden gnomes has been dispatched to ' \
            'look into the problem.',
        )
      end

      # Require authentication for non static files if authentication is
      # enabled.
      before %r{^((?!.css|.jpg|.png|.js|.ico).)+$} do
        authenticate! if Configuration.authentication?
      end

      ##
      # Shows a form that allows users to submit data directly from their
      # browser.
      #
      get '/' do
        erb :index
      end

      ##
      # Processes the input using a component.
      #
      # Data can be submitted in two ways:
      #
      # 1. As regular POST fields
      # 2. A single JSON object as the POST body
      #
      # When submitting data, you can use the following fields (either as POST
      # fields or as the fields of a JSON object):
      #
      # | Field          | Description                                 |
      # |:---------------|:--------------------------------------------|
      # | input          | The raw input text/KAF to process           |
      # | input_url      | A URL to a document to download and process |
      # | callbacks      | An array of callback URLs                   |
      # | error_callback | A URL to submit errors to                   |
      # | request_id     | A unique ID to associate with the document  |
      # | metadata       | A custom metadata object to store in S3     |
      #
      # In case of a JSON object the input body would look something like the
      # following:
      #
      #     {"input": "Hello world, this is....", request_id: "123abc"}
      #
      post '/' do
        if json_input?
          options = params_from_json
        else
          options = params
        end

        options   = InputSanitizer.new.prepare_parameters(options)
        has_input = false

        INPUT_FIELDS.each do |field|
          if options[field] and !options[field].empty?
            has_input = true

            break
          end
        end

        unless has_input
          halt(400, 'No input specified in the "input" or "input_url" field')
        end

        if options['callbacks'] and !options['callbacks'].empty?
          process_async(options)
        else
          process_sync(options)
        end
      end

      ##
      # Processes a request synchronously, results are sent as the response upon
      # completion.
      #
      # @param [Hash] options
      # @return [String]
      #
      def process_sync(options)
        output, ctype = analyze(options)

        content_type(ctype)

        return output
      end

      ##
      # Processes a request asynchronously, results are submitted to the next
      # callback URL.
      #
      # @param [Hash] options
      # @return [Hash]
      #
      def process_async(options)
        request_id = options['request_id'] || SecureRandom.hex
        final_url  = options['callbacks'].last

        async { analyze_async(options, request_id) }

        content_type :json

        return JSON.dump(
          :request_id => request_id,
          :output_url => "#{final_url}/#{request_id}"
        )
      end

      ##
      # Analyzes the input and returns an Array containing the output and
      # content type.
      #
      # @param [Hash] options
      # @return [Array]
      #
      def analyze(options)
        comp_options = InputSanitizer.new.whitelist_options(
          options,
          self.class.accepted_params
        )

        input     = InputExtractor.new.extract(options)
        processor = self.class.text_processor.new(comp_options)
        output    = processor.run(input)

        if processor.respond_to?(:output_type)
          type = processor.output_type
        else
          type = :xml
        end

        return output, type
      end

      ##
      # Analyzes the input asynchronously.
      #
      # @param [Hash] options
      # @param [String] request_id
      #
      def analyze_async(options, request_id)
        output, _ = analyze(options)

        submit_output(output, request_id, options)

      # Submit the error to the error callback, re-raise so Rollbar can also
      # report it.
      rescue Exception => error
        ErrorHandler.new.submit(error, request_id) if options['error_callback']

        raise error
      end

      ##
      # Submits the output to the next callback URL.
      #
      # @param [String] output
      # @param [String] request_id
      # @param [Hash] options
      #
      def submit_output(output, request_id, options)
        callbacks = options['callbacks'].dup
        next_url  = callbacks.shift

        # Re-use the old payload so that any extra data (e.g. metadata) is kept
        # in place.
        new_payload = options.merge(
          'callbacks'  => callbacks,
          'request_id' => request_id
        )

        # Make sure we don't re-send this to the next component.
        new_payload.delete('input')

        if Configuration.output_bucket
          uploader = Uploader.new
          object   = uploader.upload(request_id, output, options['metadata'])

          new_payload['input_url'] = object.url_for(:read, :expires => 3600)
        else
          new_payload['input'] = output
        end

        CallbackHandler.new.post(next_url, new_payload)
      end

      ##
      # Returns a Hash containing the parameters from a JSON payload. The keys
      # of this Hash are returned as _strings_ to prevent Symbol DOS attacks.
      #
      # @return [Hash]
      #
      def params_from_json
        return JSON.load(request.body.read)
      end

      ##
      # Returns `true` if the input data is in JSON, false otherwise
      #
      # @return [TrueClass|FalseClass]
      #
      def json_input?
        return request.content_type == 'application/json'
      end

      ##
      # Authenticates the current request.
      #
      def authenticate!
        token  = Configuration.authentication_token
        secret = Configuration.authentication_secret
        creds  = {token => params[token], secret => params[secret]}

        response = HTTPClient.get(Configuration.authentication_endpoint, creds)

        unless response.ok?
          halt(403, "Authentication failed: #{response.body}")
        end
      end

      ##
      # Runs the block in a separate thread. When running a test environment the
      # block is instead yielded normally.
      #
      def async
        if self.class.environment == :test
          yield
        else
          Thread.new { yield }
        end
      end
    end # Server
  end # Webservice
end # Opener
