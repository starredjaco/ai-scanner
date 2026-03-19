require 'rails_helper'

class TestService < ApplicationService
  def initialize(param1, param2 = nil)
    @param1 = param1
    @param2 = param2
  end

  def call
    "Called with #{@param1} and #{@param2}"
  end
end

RSpec.describe ApplicationService do
  describe '.call' do
    it 'instantiates the service and calls #call' do
      result = TestService.call("test")
      expect(result).to eq("Called with test and ")
    end

    it 'passes all arguments to the initializer' do
      result = TestService.call("test", "another")
      expect(result).to eq("Called with test and another")
    end
  end
end
