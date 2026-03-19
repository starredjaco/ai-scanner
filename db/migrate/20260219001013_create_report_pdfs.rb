class CreateReportPdfs < ActiveRecord::Migration[8.1]
  def change
    create_table :report_pdfs do |t|
      t.references :report, null: false, foreign_key: true, index: { unique: true }
      t.integer :status, null: false, default: 0
      t.string :file_path
      t.text :error_message

      t.timestamps
    end

    add_index :report_pdfs, :status
  end
end
