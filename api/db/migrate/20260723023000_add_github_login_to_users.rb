# frozen_string_literal: true

class AddGithubLoginToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :github_login, :string
    add_index :users, :github_login, unique: true
  end
end
