# frozen_string_literal: true

class MigrateParallelAttemptsToSettings < ActiveRecord::Migration[8.0]
  def up
    # Find the existing PARALLEL_ATTEMPTS value from EnvironmentVariable
    existing_env_var = EnvironmentVariable.find_by(env_name: "PARALLEL_ATTEMPTS", target_id: nil)

    if existing_env_var
      value = existing_env_var.env_value

      # Only create the Metadatum if it doesn't already exist
      unless Metadatum.exists?(key: "parallel_attempts")
        Metadatum.create!(key: "parallel_attempts", value: value)
        Rails.logger.info("Migrated PARALLEL_ATTEMPTS=#{value} to Settings")
      end
    end

    # Check for target-specific PARALLEL_ATTEMPTS and log a warning
    target_specific_count = EnvironmentVariable.where(env_name: "PARALLEL_ATTEMPTS").where.not(target_id: nil).count
    if target_specific_count > 0
      Rails.logger.warn("Found #{target_specific_count} target-specific PARALLEL_ATTEMPTS entries. " \
                        "These will be deleted. The global setting will apply to all targets.")
    end

    # Delete all PARALLEL_ATTEMPTS EnvironmentVariable records (global and target-specific)
    deleted_count = EnvironmentVariable.where(env_name: "PARALLEL_ATTEMPTS").delete_all
    Rails.logger.info("Deleted #{deleted_count} PARALLEL_ATTEMPTS EnvironmentVariable record(s)")
  end

  def down
    # Recreate the global PARALLEL_ATTEMPTS EnvironmentVariable with current Settings value
    current_value = Metadatum.find_by(key: "parallel_attempts")&.value || "16"

    EnvironmentVariable.find_or_create_by!(env_name: "PARALLEL_ATTEMPTS", target_id: nil) do |env|
      env.env_value = current_value
    end

    # Delete the Metadatum
    Metadatum.where(key: "parallel_attempts").delete_all

    Rails.logger.info("Rolled back: Recreated PARALLEL_ATTEMPTS EnvironmentVariable with value=#{current_value}")
  end
end
