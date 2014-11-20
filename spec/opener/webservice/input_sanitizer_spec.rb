require 'spec_helper'

describe Opener::Webservice::InputSanitizer do
  before do
    @sanitizer = described_class.new
  end

  context '#prepare_parameters' do
    example 'convert string "true" to boolean true' do
      @sanitizer.prepare_parameters('foo' => 'true').should == {'foo' => true}
    end

    example 'convert string "on" to boolean true' do
      @sanitizer.prepare_parameters('foo' => 'on').should == {'foo' => true}
    end

    example 'convert string "false" to boolean false' do
      @sanitizer.prepare_parameters('foo' => 'false').should == {'foo' => false}
    end

    example 'convert Symbol keys to String keys' do
      @sanitizer.prepare_parameters(:foo => 10).should == {'foo' => 10}
    end

    example 'remove empty callback URLs' do
      @sanitizer.prepare_parameters('callbacks' => ['', nil]).should == {
        'callbacks' => []
      }
    end

    example 'remove empty error callback URLs' do
      @sanitizer.prepare_parameters('error_callback' => '').should == {}
    end
  end

  context '#whitelist_options' do
    example 'whitelist a set of options' do
      input     = {'foo' => 10, 'baz' => 20}
      whitelist = [:foo, :bar]
      options   = @sanitizer.whitelist_options(input, whitelist)

      options.should == {:foo => 10}
    end
  end
end
