class CreateTopics < ActiveRecord::Migration
  def change

  	create_table :topics do |t|
      t.integer :tid
      t.integer :forumid
      t.string :title
      t.text :body
      t.text :json
      t.boolean :edited, default: false

      t.timestamps
      t.has_many :audits
      t.belongs_to :forums
      t.has_many :attachments
    end
    
  end

  def up
    
  end

  def down
    drop_table :topics
  end

end
