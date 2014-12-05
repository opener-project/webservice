require 'spec_helper'

describe Opener::Webservice::Server, :type => :request do
  before do
    @processor = Class.new do
      def initialize(*); end

      def run(input)
        return <<-EOF
<?xml version="1.0" ?>
<KAF version="1.2">
  <raw>#{input}</raw>
</KAF>
        EOF
      end
    end

    described_class.stub(:text_processor).and_return(@processor)
    described_class.stub(:accepted_params).and_return([:kaf])

    @server = described_class.new!
  end

  after do
    Opener::Webservice::Transaction.reset_current
  end

  context 'synchronous requests' do
    example 'require the "input" or "input_url" field to be set' do
      post('/').status.should == 400
    end

    example 'process a request' do
      described_class.any_instance.should_receive(:process_sync)

      post('/', :input => 'Hello world')
    end

    example 'process a JSON request' do
      described_class.any_instance.should_receive(:process_sync)

      post(
        '/',
        {:input => 'Hello world'},
        {'HTTP_CONTENT_TYPE' => 'application/json'}
      )
    end
  end

  context 'asynchronous requests' do
    example 'require the "input" or "input_url" field to be set' do
      post('/').status.should == 400
    end

    example 'process a request' do
      described_class.any_instance.should_receive(:process_async)

      post('/', :input => 'Hello world', :callbacks => %w{http://foo})
    end

    example 'process a JSON request' do
      described_class.any_instance.should_receive(:process_async)

      post(
        '/',
        {:input => 'Hello world', :callbacks => %w{http://foo}},
        {'HTTP_CONTENT_TYPE' => 'application/json'}
      )
    end
  end

  context '#process_sync' do
    example 'set the content type' do
      @server.should_receive(:content_type).with(:xml)

      @server.process_sync('input' => 'Hello world')
    end

    example 'return the output' do
      @server.stub(:content_type)

      output = @server.process_sync('input' => 'Hello world')

      output.should =~ /Hello world/
    end
  end

  context '#process_async' do
    before do
      @input = {'input' => 'Hello world', 'callbacks' => %w{http://foo}}
    end

    example 'set the content type to JSON' do
      @server.should_receive(:content_type).with(:json)
      @server.stub(:analyze_async)

      @server.process_async(@input)
    end

    example 'analyze the input in the background' do
      @server.stub(:content_type)

      @server.should_receive(:analyze_async)
        .with(@input, an_instance_of(String))

      @server.process_async(@input)
    end

    example 'analyze the input using a custom request ID' do
      input = @input.merge('request_id' => '123')

      @server.stub(:content_type)

      @server.should_receive(:analyze_async)
        .with(input, '123')

      @server.process_async(input)
    end

    example 'return a JSON object containing status details' do
      @server.stub(:content_type)
      @server.stub(:analyze_async)

      retval = JSON.load(@server.process_async(@input))

      retval['request_id'].empty?.should == false
      retval['output_url'].should        == "http://foo/#{retval['request_id']}"
    end
  end

  context '#analyze' do
    example 'pass whitelisted options to the processor' do
      instance = @processor.new

      @processor.should_receive(:new)
        .with(:kaf => true)
        .and_return(instance)

      @server.analyze('input' => 'Hello world', 'foo' => 'bar', 'kaf' => true)
    end

    example 'return the default content type' do
      @server.analyze('input' => 'Hello world')[1].should == :xml
    end

    example 'return a custom content type if specified' do
      @processor.any_instance.stub(:output_type).and_return(:json)

      @server.analyze('input' => 'Hello world')[1].should == :json
    end

    example 'return the processor output' do
      @server.analyze('input' => 'Hello world')[0].should =~ /Hello world/
    end

    example 'store input parameters in the current transaction' do
      params = {'input' => 'Hello world'}

      @server.analyze(params)

      Opener::Webservice::Transaction.current.parameters.should == params
    end

    example 'include only up to 256 bytes of raw input in the transaction' do
      params = {'input' => 'a' * 400}

      @server.analyze(params)

      transaction = Opener::Webservice::Transaction.current

      transaction.parameters['input'].length.should == 256
    end
  end

  context '#analyze_async' do
    before do
      @input = {'input' => 'Hello world', 'error_callback' => 'foo'}
    end

    example 'analyze the input and submit the output to a callback' do
      @server.should_receive(:submit_output)
        .with(an_instance_of(String), '123', @input)

      @server.analyze_async(@input, '123')
    end

    example 'submit errors to the error callback if present' do
      Opener::Webservice::ErrorHandler.any_instance
        .should_receive(:submit)
        .with(an_instance_of(StandardError), '123')

      @server.stub(:analyze).and_raise(StandardError)

      -> { @server.analyze_async(@input, '123') }.should raise_error
    end

    example 'simply re-raise errors if no error callback is present' do
      @input.delete('error_callback')

      @server.stub(:analyze).and_raise(StandardError)

      -> { @server.analyze_async(@input, '123') }.should raise_error
    end
  end

  context '#submit_output' do
    before do
      @input = {
        'input'     => 'Hello world',
        'callbacks' => %w{http://foo},
        'metadata'  => {'user_id' => 2}
      }
    end

    example 'submit the output to the next callback' do
      new_payload = {
        'metadata'   => {'user_id' => 2},
        'callbacks'  => [],
        'request_id' => '123',
        'input'      => 'Hello world'
      }

      Opener::CallbackHandler.any_instance
        .should_receive(:post)
        .with('http://foo', new_payload)

      @server.submit_output('Hello world', '123', @input)
    end

    example 'upload the output to S3 and submit the URL to the next callback' do
      new_payload = {
        'metadata'   => {'user_id' => 2},
        'callbacks'  => [],
        'request_id' => '123',
        'input_url'  => 'http://s3-example'
      }

      s3_object = AWS::S3::S3Object.new('foo', 'bar')

      s3_object.should_receive(:url_for)
        .and_return(new_payload['input_url'])

      Opener::CallbackHandler.any_instance
        .should_receive(:post)
        .with('http://foo', new_payload)

      Opener::Webservice::Configuration.stub(:output_bucket)
        .and_return('example-bucket')

      Opener::Webservice::Uploader.any_instance
        .should_receive(:upload)
        .and_return(s3_object)

      @server.submit_output('Hello world', '123', @input)
    end
  end

  context '#params_from_json' do
    example 'parse the request body as JSON' do
      request = double(:request, :body => StringIO.new('[10]'))

      @server.stub(:request).and_return(request)

      @server.params_from_json.should == [10]
    end
  end

  context '#json_input?' do
    before do
      @request = double(:request)

      @server.stub(:request).and_return(@request)
    end

    example 'return true if the Content-Type is set to JSON' do
      @request.stub(:content_type).and_return('application/json')

      @server.json_input?.should == true
    end

    example 'return false if the Content-Type is not set to JSON' do
      @request.stub(:content_type).and_return('text/html')

      @server.json_input?.should == false
    end
  end

  context '#authenticate!' do
    before do
      Opener::Webservice::Configuration.stub(:authentication_token)
        .and_return('token')

      Opener::Webservice::Configuration.stub(:authentication_secret)
        .and_return('secret')

      Opener::Webservice::Configuration.stub(:authentication_endpoint)
        .and_return('foo')
    end

    example 'authenticate using a remote service' do
      message = HTTP::Message.new_response('Yup')

      HTTPClient.any_instance
        .should_receive(:get)
        .with('foo', 'token' => '123', 'secret' => '456')
        .and_return(message)

      @server.stub(:params).and_return('token' => '123', 'secret' => '456')

      @server.authenticate!
    end

    example 'deny access if authentication failed' do
      message = HTTP::Message.new_response('Yup')

      message.status = 403

      HTTPClient.any_instance
        .should_receive(:get)
        .with('foo', 'token' => '123', 'secret' => '456')
        .and_return(message)

      @server.stub(:params).and_return('token' => '123', 'secret' => '456')

      @server.should_receive(:halt).with(403, an_instance_of(String))
      @server.authenticate!
    end
  end
end
