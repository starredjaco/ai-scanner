# frozen_string_literal: true

class DropActiveAdminComments < ActiveRecord::Migration[8.0]
  def up
    drop_table :active_admin_comments, if_exists: true
  end

  def down
    # Table was unused (comments disabled) - no need to recreate
  end
end
