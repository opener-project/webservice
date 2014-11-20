require 'spec_helper'

describe Opener::Webservice::Uploader do
  before do
    @uploader = described_class.new
  end

  context '#upload' do
    example 'upload a document to S3' do
      @uploader.should_receive(:create).with(
        'foo.xml',
        'Hello',
        :metadata     => {:a => 10},
        :content_type => 'application/xml'
      )

      @uploader.upload('foo', 'Hello', :a => 10)
    end
  end
end
