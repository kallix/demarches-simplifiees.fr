require 'spec_helper'

describe CommentairesController, type: :controller do
  let(:dossier) { create(:dossier) }
  let(:dossier_id) { dossier.id }
  let(:email_commentaire) { 'test@test.com' }
  let(:texte_commentaire) { 'Commentaire de test' }

  describe '#POST create' do
    context 'création correct d\'un commentaire' do
      it 'depuis la page récapitulatif' do
        post :create, dossier_id: dossier_id, email_commentaire: email_commentaire, texte_commentaire: texte_commentaire
        expect(response).to redirect_to("/dossiers/#{dossier_id}/recapitulatif")
      end
    end
  end
end
