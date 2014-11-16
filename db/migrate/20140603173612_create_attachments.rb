class CreateAttachments < ActiveRecord::Migration
  def change

  	create_table :attachments do |t|

  	t.integer :tid	
    t.string :name
    t.text :url
    t.text :path

    t.timestamps
    t.belongs_to :topics
    end
  
  end

  def up

    
  end

  def down
    drop_table :attachments
  end

end
