require 'sinatra/base'
require 'optparse'

module Opener
  class Webservice < Sinatra::Base
    class OptParser
      attr_accessor :option_parser, :options

      def initialize(&block)
        @options = {}
        @option_parser = construct_option_parser(options, &block)
      end

      def parse(args)
        process(:parse, args)
      end

      def parse!(args)
        process(:parse!, args)
      end

      def pre_parse!(args)
        delete_double_dash = false
        process(:parse!, args, delete_double_dash)
      end

      def pre_parse(args)
        delete_double_dash = false
        process(:parse, args, delete_double_dash)
      end

      def self.parse(args)
        new.parse(args)
      end

      def self.parse!(args)
        new.parse!(args)
      end

      def self.pre_parse!(args)
        new.pre_parse!(args)
      end

      def self.pre_parse(args)
        new.pre_parse(args)
      end

      private

      def process(call, args, delete_double_dash=true)
        args.delete("--") if delete_double_dash
        option_parser.send(call, args)
        return options
      end

      def construct_option_parser(options, &block)
        script_name = File.basename($0, ".rb")

        OptionParser.new do |opts|
          if block_given?
            opts.banner = "Usage: #{script_name} <start> [server_options] -- [authentication_options]"
          else
            opts.banner = "Usage: #{script_name} <start> [options]"
          end

          opts.separator ""

          if block_given?
            opts.separator "Component Specific options:"
            opts.separator ""
            yield opts, options
            opts.separator ""
          end

          opts.separator "Authentication options:"

          opts.on("-a", "--authentication AUTHENTICATION_ENDPOINT", "Endpoint for authenticating requests") do |v|
            Sinatra::Application.set :authentication, v
          end

          opts.separator ""

          opts.separator "Common options:"

          # No argument, shows at tail.  This will print an options summary.
          # Try it and see!
          opts.on_tail("-h", "--help", "Show this message. Usage: #{script_name} -h") do
            puts opts
            exit
          end
        end
      end
    end
  end
end
