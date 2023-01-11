class AddMigratedChampRoutageToDossiers < ActiveRecord::Migration[6.1]
  def change
    add_column :dossiers, :migrated_champ_routage, :boolean, default: false, null: false
    add_column :procedures, :migrated_champ_routage, :boolean, default: false, null: false
    add_column :procedure_revisions, :migrated_champ_routage, :boolean, default: false, null: false
  end
end
