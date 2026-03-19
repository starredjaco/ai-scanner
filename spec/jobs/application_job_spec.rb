require "rails_helper"
require "logging"

class TestJob < ApplicationJob
  def perform(should_fail = false)
    raise StandardError, "Test error" if should_fail
    "success"
  end
end

class ParentJob < ApplicationJob
  def perform
    ChildJob.perform_now
  end
end

class ChildJob < ApplicationJob
  def perform
    "child result"
  end
end

class JobWithArgs < ApplicationJob
  def perform(arg1, arg2 = "default")
    "#{arg1} #{arg2}"
  end
end

RSpec.describe ApplicationJob, type: :job do
  describe "logging behavior" do
    let(:job) { TestJob.new }
    let(:logger) { instance_double(ActiveSupport::Logger) }

    before do
      allow(Rails).to receive(:logger).and_return(logger)
      allow(logger).to receive(:info)
      allow(logger).to receive(:error)
    end

    context "when job succeeds" do
      it "logs job start and completion with duration" do
        # Expect start log
        expect(logger).to receive(:info).with("job.started")

        # Expect completion log with duration
        expect(logger).to receive(:info).with("job.finished")

        job.perform_now
      end

      it "includes job context in logs" do
        logged_contexts = []

        allow(logger).to receive(:info) do |msg|
          logged_contexts << Logging.context.dup
          msg
        end

        job.perform_now

        # Both start and completion should have job context
        expect(logged_contexts).to all(include(
          job_class: "TestJob",
          job_id: be_a(String)
        ))
      end

      it "measures job execution time accurately" do
        duration_ms = nil

        allow(logger).to receive(:info) do |msg|
          if Logging.context[:duration_ms]
            duration_ms = Logging.context[:duration_ms]
          end
          msg
        end

        # Add a small delay to ensure measurable duration
        allow(job).to receive(:perform).and_wrap_original do |method, *args|
          sleep(0.01)
          method.call(*args)
        end

        job.perform_now

        expect(duration_ms).to be > 0
        expect(duration_ms).to be < 1000 # Should be less than 1 second
      end
    end

    context "when job fails" do
      it "logs job start and error with exception details" do
        # Expect start log
        expect(logger).to receive(:info).with("job.started")

        # Expect error log with exception details
        expect(logger).to receive(:error).with("job.failed")

        # Expect finish log even on failure
        expect(logger).to receive(:info).with("job.finished")

        expect { TestJob.perform_now(true) }.to raise_error(StandardError, "Test error")
      end

      it "includes duration even when job fails" do
        finish_duration = nil

        allow(logger).to receive(:info) do |msg|
          if Logging.context[:duration_ms] && msg == "job.finished"
            finish_duration = Logging.context[:duration_ms]
          end
          msg
        end
        allow(logger).to receive(:error)

        expect { TestJob.perform_now(true) }.to raise_error(StandardError)

        expect(finish_duration).to be_a(Integer)
        expect(finish_duration).to be >= 0
      end

      it "preserves original exception" do
        allow(logger).to receive(:error)
        allow(logger).to receive(:info)

        expect { TestJob.perform_now(true) }.to raise_error(StandardError, "Test error")
      end
    end

    context "with nested job execution" do
      it "maintains separate logging contexts for each job" do
        parent_job = ParentJob.new
        logged_contexts = []

        allow(logger).to receive(:info) do |msg|
          logged_contexts << Logging.context.dup
          msg
        end

        parent_job.perform_now

        # Should have logs for both parent and child
        parent_contexts = logged_contexts.select { |c| c[:job_class] == "ParentJob" }
        child_contexts = logged_contexts.select { |c| c[:job_class] == "ChildJob" }

        expect(parent_contexts).not_to be_empty
        expect(child_contexts).not_to be_empty

        # Each should have unique job IDs
        parent_ids = parent_contexts.map { |c| c[:job_id] }.uniq
        child_ids = child_contexts.map { |c| c[:job_id] }.uniq

        expect(parent_ids.size).to eq(1)
        expect(child_ids.size).to eq(1)
        expect(parent_ids.first).not_to eq(child_ids.first)
      end
    end

    context "with ActiveJob features" do
      it "works with job arguments" do
        job = JobWithArgs.new
        allow(logger).to receive(:info)

        expect { JobWithArgs.perform_now("test", "value") }.not_to raise_error
      end

      it "includes job ID from ActiveJob" do
        job_id = nil

        allow(logger).to receive(:info) do |msg|
          job_id = Logging.context[:job_id]
          msg
        end

        job.perform_now

        expect(job_id).to match(/^[a-f0-9-]+$/) # UUID format
      end
    end
  end

  describe "performance monitoring" do
    let(:job) { TestJob.new }
    let(:logger) { instance_double(ActiveSupport::Logger) }

    before do
      allow(Rails).to receive(:logger).and_return(logger)
      allow(logger).to receive(:info)
      allow(logger).to receive(:error)
    end

    it "uses monotonic clock for accurate timing" do
      # Verify Process.clock_gettime is called with CLOCK_MONOTONIC
      # Allow both with just the constant and with additional parameters
      allow(Process).to receive(:clock_gettime).and_call_original

      job.perform_now

      expect(Process).to have_received(:clock_gettime).with(Process::CLOCK_MONOTONIC).at_least(:twice)
    end

    it "rounds duration to nearest millisecond" do
      duration_ms = nil

      allow(logger).to receive(:info) do |msg|
        if Logging.context[:duration_ms]
          duration_ms = Logging.context[:duration_ms]
        end
        msg
      end

      job.perform_now

      expect(duration_ms).to be_a(Integer)
    end
  end
end
