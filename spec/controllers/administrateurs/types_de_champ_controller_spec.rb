describe Administrateurs::TypesDeChampController, type: :controller do
  let(:admin) { create(:administrateur) }

  describe '#types_de_champs editor' do
    let(:procedure) { create(:procedure) }

    before do
      admin.procedures << procedure
      sign_in(admin.user)
    end

    let(:type_champ) { TypeDeChamp.type_champs.fetch(:text) }

    context "create type_de_champ text" do
      before do
        post :create, params: {
          procedure_id: procedure.id,
          type_de_champ: {
            type_champ: type_champ,
            libelle: 'Nouveau champ',
            private: false,
            placeholder: "custom placeholder"
          }
        }, format: :turbo_stream
      end

      it { expect(response).to have_http_status(:ok) }
    end

    context "validate type_de_champ linked_drop_down_list" do
      let(:type_champ) { TypeDeChamp.type_champs.fetch(:linked_drop_down_list) }

      before do
        post :create, params: {
          procedure_id: procedure.id,
          type_de_champ: {
            type_champ: type_champ,
            libelle: 'Nouveau champ',
            private: false
          }
        }, format: :turbo_stream
      end

      it { expect(response).to have_http_status(:ok) }
    end

    context "create type_de_champ linked_drop_down_list" do
      let(:type_champ) { TypeDeChamp.type_champs.fetch(:linked_drop_down_list) }

      before do
        post :create, params: {
          procedure_id: procedure.id,
          type_de_champ: {
            type_champ: type_champ,
            libelle: 'Nouveau champ',
            drop_down_list_value: '--value--',
            private: false
          }
        }, format: :turbo_stream
      end

      it { expect(response).to have_http_status(:ok) }
    end
  end
end
