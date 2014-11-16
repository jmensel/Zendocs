class CreateForums < ActiveRecord::Migration
  def change

  	create_table :forums do |t|

      t.integer :fid
      t.string :name

      t.timestamps
    end
    
  end

  def up
    
  end

  def down
    drop_table :forums
  end

end