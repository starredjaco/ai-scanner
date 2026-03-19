FactoryBot.define do
  factory :environment_variable do
    sequence(:env_name) { |n| "ENV_VAR_#{n}" }
    env_value { "test_value" }
    company { ActsAsTenant.current_tenant || association(:company) }

    trait :with_target do
      association :target
    end

    factory :global_environment_variable do
      target { nil }
    end
  end
end
