class CreateFeedbacks < ActiveRecord::Migration[5.1]
  def change
    create_table :feedbacks do |t|
      t.string :module
      t.boolean :like, default: true
      t.references :user, foreign_key: true, index: true
      t.references :company, foreign_key: true, index: true

      t.timestamps
    end
  end
end
