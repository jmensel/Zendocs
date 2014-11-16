class Createaudits < ActiveRecord::Migration
  def change
  	create_table :audits do |t|
      t.string :username
      t.text :notes
      t.text :body

      t.timestamps
      t.belongs_to :topics
    end
  end
end
