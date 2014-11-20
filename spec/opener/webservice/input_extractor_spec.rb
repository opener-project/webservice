require 'spec_helper'

describe Opener::Webservice::InputExtractor do
  before do
    @extractor = described_class.new
  end

  context '#extract' do
    example 'extract the input directly from the parameters' do
      @extractor.extract('input' => 'foo').should == 'foo'
    end

    example 'extract the input from a URL' do
      url     = 'http://foo.com'
      message = HTTP::Message.new_response('foo')

      @extractor.http.should_receive(:get).with(url, an_instance_of(Hash))
        .and_return(message)

      @extractor.extract('input_url' => url).should == 'foo'
    end

    example 'raise RuntimeError if the input could not be downloaded' do
      url     = 'http://foo.com'
      message = HTTP::Message.new_response('foo')

      message.status = 404

      @extractor.http.should_receive(:get).with(url, an_instance_of(Hash))
        .and_return(message)

      -> { @extractor.extract('input_url' => url) }.should raise_error
    end
  end
end
