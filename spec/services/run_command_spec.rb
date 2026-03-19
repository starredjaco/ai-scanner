require 'rails_helper'

RSpec.describe RunCommand do
  describe '#call' do
    it 'returns the stdout when command is successful' do
      command_service = RunCommand.new('echo "hello"')
      result = command_service.call
      expect(result).to eq("hello\n")
    end

    it 'raises an error when command fails' do
      command_service = RunCommand.new('exit 1')
      expect { command_service.call }.to raise_error(/Command failed with error/)
    end
  end

  describe '#call_async' do
    it 'returns a process object' do
      command_service = RunCommand.new('echo "async test"')
      result = command_service.call_async
      expect(result).to be_a(Process::Waiter)
    end
  end
end
