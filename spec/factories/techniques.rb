FactoryBot.define do
  factory :technique do
    sequence(:name) { |n| "#{Faker::Hacker.adjective} #{Faker::Hacker.noun} #{n}" }
    path { "techniques/#{name.parameterize}" }
  end
end
