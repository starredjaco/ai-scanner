FactoryBot.define do
  factory :raw_report_data do
    report
    jsonl_data { '{"entry_type": "init", "start_time": "2023-01-01T00:00:00Z"}' }
    logs_data { nil }
    status { :pending }
  end
end
