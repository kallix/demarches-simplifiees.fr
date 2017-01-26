require 'spec_helper'

describe Admin::MailTemplatesController, type: :controller do
  let(:mail_template) { create :mail_template, :dossier_received }
  let(:procedure) { create :procedure, mail_templates: [mail_template]}

  before do
    sign_in procedure.administrateur
  end

  describe 'GET index' do
    render_views

    subject { get :index, params: {procedure_id: procedure.id} }

    it { expect(subject.status).to eq 200 }
    it { expect(subject.body).to include("E-mails personnalisables") }
    it { expect(subject.body).to include(*procedure.mail_templates.map{ |mt| mt.decorate.name }) }
  end

  describe 'PATCH update' do
    let(:object) { 'plop modif' }
    let(:body) { 'plip modif' }

    context 'when is mail_template id' do
      subject { patch :update,
                      params: {procedure_id: mail_template.procedure.id,
                               id: mail_template.id,
                               mail_template: {
                                   object: object,
                                   body: body
                               }} }

      it { expect(subject).to redirect_to admin_procedure_mail_templates_path(mail_template.procedure) }

      it {
        expect {
            subject
            mail_template.reload
        }.to change(mail_template, :object).from("[TPS] Accusé de réception pour votre dossier n°--numero_dossier--").to(object)
      }

      it {
        expect {
            subject
            mail_template.reload
        }.to change(mail_template, :body).from("Votre administration vous confirme la bonne réception de votre dossier n°--numero_dossier--").to(body)
      }
    end
  end
end
