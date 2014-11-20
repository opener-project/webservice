require 'spec_helper'

describe Opener::Webservice::ErrorHandler do
  before do
    @handler = described_class.new
  end

  context '#submit' do
    example 'submit an error to the error callback' do
      @handler.http.should_receive(:post)
        .with('http://foo', :body => {:error => 'Hello', :request_id => '123'})

      error = RuntimeError.new('Hello')

      @handler.submit(error, '123', 'http://foo')
    end
  end
end
