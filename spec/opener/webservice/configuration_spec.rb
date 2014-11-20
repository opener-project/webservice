require 'spec_helper'

describe Opener::Webservice::Configuration do
  context 'authentication?' do
    example 'return true if authentication should be enabled' do
      described_class.stub(:authentication_endpoint).and_return('foo')

      described_class.authentication?.should == true
    end

    example 'return false if authentication should be disabled' do
      described_class.authentication?.should == false
    end
  end

  context 'syslog?' do
    after do
      ENV.delete('ENABLE_SYSLOG')
    end

    example 'return true if Syslog should be enabled' do
      ENV['ENABLE_SYSLOG'] = '1'

      described_class.syslog?.should == true
    end

    example 'return false if Syslog should be disabled' do
      described_class.syslog?.should == false
    end
  end
end
