class AddOutputServerToScan < ActiveRecord::Migration[8.0]
  def change
    add_reference :scans, :output_server, foreign_key: true, index: true
  end
end
