class MockTargetSetupService
  attr_reader :target, :scan, :report, :company

  MOCK_TARGET_CONFIG = {
    "rest" => {
      "RestGenerator" => {
        "name" => "Mock LLM for Scanner Testing",
        "uri" => "http://localhost:3000/api/v1/mock_llm/chat",
        "method" => "post",
        "req_template_json_object" => {
          "text" => "$INPUT"
        },
        "response_json" => true,
        "response_json_field" => "text",
        "request_timeout" => 30
      }
    }
  }.freeze

  def self.call(company: nil)
    new(company: company).call
  end

  def initialize(company: nil)
    @company = company || find_or_create_default_company
  end

  def call
    ActsAsTenant.with_tenant(company) do
      create_mock_target
      create_basic_scan
      create_and_run_report

      {
        target: target,
        scan: scan,
        report: report,
        message: "Mock LLM target created successfully. Scan initiated with ID: #{report.uuid}"
      }
    end
  end

  private

  def find_or_create_default_company
    Company.find_or_create_by!(name: "Mock LLM Testing Company") do |c|
      c.tier = :tier_4
    end
  end

  def create_mock_target
    @target = Target.find_or_create_by(
      name: "Mock LLM Test Target",
      model_type: "RestGenerator",
      model: "rest",
      company: company
    ) do |t|
      t.description = "Mock LLM interface for scanner validation and testing"
      t.json_config = MOCK_TARGET_CONFIG.to_json
    end

    # Ensure the target has the latest config
    if target.json_config != MOCK_TARGET_CONFIG.to_json
      target.update!(json_config: MOCK_TARGET_CONFIG.to_json)
    end
  end

  def create_basic_scan
    @scan = Scan.find_or_create_by(name: "Mock LLM Basic Validation Scan", company: company)

    # Add probes to the scan if not already present
    probe_names = [
      "LitmusTest",           # Will pass - connectivity test
      "ChemicalSynthesis",    # Will fail - harmful content (if available)
      "BasicHarmlessPrompts", # Will pass - safe prompts (if available)
      "SimpleQuestions",      # Will pass - basic queries (if available)
      "PolicyViolation"       # Will pass - policy check (if available)
    ]

    # Find available probes and add them to scan
    available_probes = Probe.where(name: probe_names).enabled.limit(5)

    # If we don't have enough specific probes, get any 5 enabled probes
    if available_probes.count < 5
      available_probes = Probe.enabled.limit(5)
    end

    scan.probes = available_probes
    scan.targets << target unless scan.targets.include?(target)
    scan.save!
  end

  def create_and_run_report
    @report = Report.create!(
      target: target,
      scan: scan,
      company: company,
      uuid: SecureRandom.uuid,
      status: :pending
    )

    # Start the scan asynchronously
    RunGarakScan.new(report).call
  end
end
