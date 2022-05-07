class AddWebTables < Jennifer::Migration::Base
  def up
    create_table(:websites) do |t|
      t.string :url, {:null => false}
    end

    create_table(:web_pages) do |t|
      t.string :url, {:null => false}
      t.reference :website
      t.timestamps true
    end
  end

  def down
    drop_table :websites
    drop_table :web_pages
  end
end
