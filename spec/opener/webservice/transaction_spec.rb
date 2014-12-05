require 'spec_helper'

describe Opener::Webservice::Transaction do
  before do
    @transaction = described_class.new
  end

  after do
    described_class.reset_current
  end

  context 'current' do
    example 'memoize a Transaction instance in the current thread' do
      described_class.current.should === described_class.current
    end
  end

  context '#add_parameters' do
    example 'add a set of new parameters' do
      @transaction.add_parameters(:number => 10)

      @transaction.parameters.should == {:number => 10}
    end

    example 'add a set of parameters to an existing set' do
      @transaction.add_parameters(:a => 10)
      @transaction.add_parameters(:b => 20)

      @transaction.parameters.should == {:a => 10, :b => 20}
    end

    example 'add parameters to the New Relic transaction if this is enabled' do
      Opener::Webservice::Configuration.stub(:newrelic?).and_return(true)

      NewRelic::Agent.should_receive(:add_custom_parameters)
        .with(:a => 10)

      @transaction.add_parameters(:a => 10)
    end
  end
end
