class AddIntegrationRelationToFieldHistory < ActiveRecord::Migration[5.1]
  def change
    add_reference :field_histories, :integration_instance, foreign_key: true
  end
  

end
