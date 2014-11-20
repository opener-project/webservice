module Opener
  module Webservice
    ##
    # Sanitizes raw Sinatra input and component options.
    #
    class InputSanitizer
      ##
      # Returns a Hash containing cleaned up pairs based on the input
      # parameters. The keys of the returned Hash are String instances to
      # prevent Symbol DOS attacks.
      #
      # @param [Hash] input
      # @return [Hash]
      #
      def prepare_parameters(input)
        sanitized = {}

        input.each do |key, value|
          # Sinatra/Rack uses "on" for checked checkboxes.
          if value == 'true' or value == 'on'
            value = true
          elsif value == 'false'
            value = false
          end

          sanitized[key.to_s] = value
        end

        # Strip empty callback URLs (= default form values).
        if sanitized['callbacks']
          sanitized['callbacks'].reject! { |url| url.nil? || url.empty? }
        end

        if sanitized['error_callback'] and sanitized['error_callback'].empty?
          sanitized.delete('error_callback')
        end

        return sanitized
      end

      ##
      # Returns a Hash containing the whitelisted options to pass to a
      # component. Since components use Symbols for their options this Hash uses
      # Symbols for its keys.
      #
      # @param [Hash] input
      # @param [Array] accepted The accepted parameter names.
      # @return [Hash]
      #
      def whitelist_options(input, accepted)
        whitelisted = {}

        input.each do |key, value|
          sym_key = key.to_sym

          if accepted.include?(sym_key)
            whitelisted[sym_key] = value
          end
        end

        return whitelisted
      end
    end # InputSanitizer
  end # Webservice
end # Opener
