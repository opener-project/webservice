module Opener
  module Webservice
    ##
    # Slop wrapper for parsing webservice options and passing them to Puma.
    #
    # @!attribute [r] name
    #  The name of the component.
    #  @return [String]
    #
    # @!attribute [r] rackup
    #  Path to the config.ru to use.
    #  @return [String]
    #
    # @!attribute [r] parser
    #  @return [Slop]
    #
    class OptionParser
      attr_reader :name, :rackup, :parser

      ##
      # @param [String] name
      # @param [String] rackup
      #
      def initialize(name, rackup)
        @name   = name
        @rackup = rackup
        @parser = configure_slop
      end

      def parse(*args)
        parser.parse(*args)
      end

      ##
      # Parses the given CLI options and starts Puma.
      #
      # @param [Array] argv
      #
      def run!(argv = ARGV)
        puma_args = [rackup] + parser.parse(argv)

        unless parser[:'disable-syslog']
          ENV['ENABLE_SYSLOG'] = '1'
        end

        # Puma on JRuby does some weird stuff with forking/exec. As a result of
        # this we *have to* update ARGV as otherwise running Puma as a daemon
        # does not work.
        ARGV.replace(puma_args)

        Puma::CLI.new(puma_args).run
      end

      ##
      # @return [Slop]
      #
      def configure_slop
        outer       = self
        server_name = "#{name}-server"
        cli_name    = server_name.gsub('opener-', '')

        return Slop.new(:strict => false, :indent => 2) do
          banner "Usage: #{cli_name} [RACKUP] [OPTIONS]"

          separator <<-EOF.chomp

About:

    Runs the OpeNER component as a webservice using Puma. For example:

        language-identifier-server --daemon

    This would start a language identifier server in the background.

Environment Variables:

    These daemons make use of Amazon SQS queues and other Amazon services. In
    order to use these services you should make sure the following environment
    variables are set:

    * AWS_ACCESS_KEY_ID
    * AWS_SECRET_ACCESS_KEY
    * AWS_REGION

    If you're running this daemon on an EC2 instance then the first two
    environment variables will be set automatically if the instance has an
    associated IAM profile. The AWS_REGION variable must _always_ be set.

    Optionally you can also set the following extra variables:

    * NEWRELIC_TOKEN: when set the daemon will send profiling data to New Relic
      using this token. The application name will be "#{server_name}".

    * ROLLBAR_TOKEN: when set the daemon will report errors to Rollbar using
      this token. You can freely use this in combination with NEWRELIC_TOKEN.

Puma Options:

    This webserver uses Puma under the hood, but defines its own CLI options.
    All unrecognized options are passed to the Puma CLI. For more information
    on the available options for Puma, run `#{cli_name} --puma-help`.
          EOF

          separator "\nOptions:\n"

          on :h, :help, 'Shows this help message' do
            abort to_s
          end

          on :'puma-help', 'Shows the options of Puma' do
            Puma::CLI.new(['--help']).run

            abort
          end

          on :b=,
            :bucket=,
            'The S3 bucket to store output in',
            :as => String do |val|
              ENV['OUTPUT_BUCKET'] = val
            end

          on :authentication,
            'An authentication endpoint to use',
            :as => String do |val|
              ENV['AUTHENTICATION_ENDPOINT'] = val
            end

          on :secret,
            'Parameter name for the authentication secret',
            :as => String do |val|
              ENV['AUTHENTICATION_SECRET'] = val
            end

          on :token,
            'Parameter name for the authentication token',
            :as => String do |val|
              ENV['AUTHENTICATION_TOKEN'] = val
            end

          on :'disable-syslog', 'Disables Syslog logging (enabled by default)'
        end
      end
    end # OptionParser
  end # Webservice
end # Opener
