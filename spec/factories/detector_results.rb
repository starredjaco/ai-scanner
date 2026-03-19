FactoryBot.define do
  factory :detector_result do
    detector
    report
    passed { rand(0..100) }
    total { rand(100..200) }
    max_score { rand(1.0..5.0).round(2) }
  end
end
