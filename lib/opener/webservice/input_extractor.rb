module Opener
  module Webservice
    ##
    # Extracts the KAF/text input to use from a set of input parameters.
    #
    # @!attribute [r] http
    #  @return [HTTPClient]
    #
    class InputExtractor
      attr_reader :http

      def initialize
        @http = HTTPClient.new
      end

      ##
      # @param [Hash] options
      #
      # @option options [String] input_url A URL to download input from.
      # @option options [String] input The direct input to process.
      #
      # @return [String]
      #
      # @raise [RuntimeError] Raised when the input could not be downloaded.
      #
      def extract(options)
        if options['input_url']
          resp = http.get(options['input_url'], :follow_redirect => true)

          unless resp.ok?
            raise "Failed to download input from #{options['input_url']}"
          end

          input = resp.body
        else
          input = options['input']
        end

        return input
      end
    end # InputExtractor
  end # Webservice
end # Opener
