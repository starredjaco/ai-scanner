RSpec::Matchers.define :have_logged_with_context do |expected_context|
  match do |logged_contexts|
    logged_contexts.any? { |context| context >= expected_context }
  end

  description do
    "have logged with context #{expected_context}"
  end

  failure_message do |actual|
    "expected to find context #{expected_context} in logged contexts #{actual}"
  end
end

RSpec::Matchers.define :have_valid_job_context do
  match do |context|
    context.key?(:job_class) &&
    context.key?(:job_id) &&
    context[:job_id].match?(/^[a-f0-9-]+$/)
  end

  description do
    "have valid job context with job_class and job_id"
  end

  failure_message do |context|
    "expected context to have valid job_class and job_id, got: #{context.inspect}"
  end
end
