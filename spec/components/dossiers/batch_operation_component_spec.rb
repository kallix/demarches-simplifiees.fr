RSpec.describe Dossiers::BatchOperationComponent, type: :component do
  include ActionView::Context
  include ActionView::Helpers::FormHelper
  include ActionView::Helpers::FormOptionsHelper

  let(:component) do
    cmp = nil
    form_for(BatchOperation.new, url: Rails.application.routes.url_helpers.instructeur_batch_operations_path(procedure_id: 1), method: :post, data: { controller: 'batch-operation' }) do |_form|
      cmp = described_class.new(statut: statut, procedure: create(:procedure))
    end
    cmp
  end

  subject { render_inline(component).to_html }
  context 'statut traite' do
    let(:statut) { 'traites' }
    it { is_expected.to have_selector('input') }
  end

  context 'statut tous' do
    let(:statut) { 'tous' }
    it { is_expected.not_to have_selector('input') }
  end
end
