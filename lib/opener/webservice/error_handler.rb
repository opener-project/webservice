module Opener
  module Webservice
    ##
    # Class for handling error messages that occur when processing a document.
    #
    # @!attribute [r] http
    #  @return [HTTPClient]
    #
    class ErrorHandler
      attr_reader :http

      def initialize
        @http = HTTPClient.new
      end

      ##
      # @param [StandardError] error
      # @param [String] request_id
      # @param [String] url
      #
      def submit(error, request_id, url)
        http.post(
          url,
          :body => {:error => error.message, :request_id => request_id}
        )
      end
    end # ErrorHandler
  end # Webservice
end # Opener
