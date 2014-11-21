module Opener
  module Webservice
    ##
    # Module for storing global configuration settings such as whether or not to
    # enable authentication.
    #
    module Configuration
      ##
      # Returns `true` if authentication should be enabled.
      #
      # @return [TrueClass|FalseClass]
      #
      def self.authentication?
        return !!authentication_endpoint && !authentication_endpoint.empty?
      end

      ##
      # Returns the authentication endpoint to use.
      #
      # @return [String]
      #
      def self.authentication_endpoint
        return ENV['AUTHENTICATION_ENDPOINT']
      end

      ##
      # Returns the field name of the authentication secret.
      #
      # @return [String]
      #
      def self.authentication_secret
        return ENV['AUTHENTICATION_SECRET'] || 'secret'
      end

      ##
      # Returns the field name of the authentication token.
      #
      # @return [String]
      #
      def self.authentication_token
        return ENV['AUTHENTICATION_TOKEN'] || 'token'
      end

      ##
      # Name of the S3 bucket to store output in.
      #
      # @return [String]
      #
      def self.output_bucket
        return ENV['OUTPUT_BUCKET']
      end

      ##
      # Returns `true` if Syslog should be enabled.
      #
      # @return [TrueClass|FalseClass]
      #
      def self.syslog?
        return !!ENV['ENABLE_SYSLOG'] && !ENV['ENABLE_SYSLOG'].empty?
      end

      ##
      # Returns `true` if Rollbar error tracking should be enabled.
      #
      # @return [TrueClass|FalseClass]
      #
      def self.rollbar?
        return !!ENV['ROLLBAR_TOKEN']
      end

      ##
      # Configures Rollbar.
      #
      def self.configure_rollbar
        Rollbar.configure do |config|
          config.access_token = ENV['ROLLBAR_TOKEN']
          config.enabled      = rollbar?
          config.environment  = environment
        end
      end

      ##
      # @return [String]
      #
      def self.environment
        return ENV['RACK_ENV'] || ENV['RAILS_ENV']
      end
    end # Configuration
  end # Webservice
end # Opener
