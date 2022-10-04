class AddUserTables < Jennifer::Migration::Base
  def up
    create_table(:test_users) do |t|
      t.integer :id, {:primary => true, :null => false, :auto_increment => true}
      t.string :email
    end

    create_table(:teams) do |t|
      t.integer :id, {:primary => true, :null => false, :auto_increment => true}
      t.string :name, {:null => false}
    end

    create_table(:team_members) do |t|
      t.integer :id, {:primary => true, :null => false, :auto_increment => true}
      t.integer :role, {:null => false}
      t.reference :test_user, :integer, {:null => false}
      t.reference :team, :integer, {:null => false}
    end
  end

  def down
    drop_table :test_users
    drop_table :teams
    drop_table :team_members
  end
end
