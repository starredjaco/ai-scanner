# frozen_string_literal: true

class RenameAdminUsersToUsers < ActiveRecord::Migration[8.1]
  def change
    rename_table :admin_users, :users
  end
end
