describe SupportController, type: :controller do
  render_views

  context 'signed in' do
    before do
      sign_in user
    end

    let(:user) { create(:user) }

    it 'should not have email field' do
      get :index

      expect(response.status).to eq(200)
      expect(response.body).not_to have_content("Votre adresse email")
    end

    describe "with dossier" do
      let(:user) { dossier.user }
      let(:dossier) { create(:dossier) }

      it 'should fill dossier_id' do
        get :index, params: { dossier_id: dossier.id }

        expect(response.status).to eq(200)
        expect(response.body).to include((dossier.id).to_s)
      end
    end

    describe "with tag" do
      let(:tag) { 'yolo' }

      it 'should fill tags' do
        get :index, params: { tags: [tag] }

        expect(response.status).to eq(200)
        expect(response.body).to include(tag)
      end
    end

    describe "with multiple tags" do
      let(:tags) { ['yolo', 'toto'] }

      it 'should fill tags' do
        get :index, params: { tags: tags }

        expect(response.status).to eq(200)
        expect(response.body).to include(tags.join(','))
      end
    end

    describe "send form" do
      subject do
        post :create, params: { helpscout_form: params }
      end

      context "when invisible captcha is ignored" do
        let(:params) { { subject: 'bonjour', text: 'un message', type: 'procedure_info' } }

        it 'creates a conversation on HelpScout' do
          expect { subject }.to \
            change(Commentaire, :count).by(0).and \
            have_enqueued_job(HelpscoutCreateConversationJob).with(hash_including(params.except(:type)))

          expect(flash[:notice]).to match('Votre message a été envoyé.')
          expect(response).to redirect_to root_path
        end

        context 'when a drafted dossier is mentionned' do
          let(:dossier) { create(:dossier) }
          let(:user) { dossier.user }

          let(:params) do
            {
              dossier_id: dossier.id,
              type: Helpscout::Form::TYPE_INSTRUCTION,
              subject: 'bonjour',
              text: 'un message'
            }
          end

          it 'creates a conversation on HelpScout' do
            expect { subject }.to \
              change(Commentaire, :count).by(0).and \
              have_enqueued_job(HelpscoutCreateConversationJob).with(hash_including(subject: 'bonjour', dossier_id: dossier.id))

            expect(flash[:notice]).to match('Votre message a été envoyé.')
            expect(response).to redirect_to root_path
          end
        end

        context 'when a submitted dossier is mentionned' do
          let(:dossier) { create(:dossier, :en_construction) }
          let(:user) { dossier.user }

          let(:params) do
            {
              dossier_id: dossier.id,
              type: Helpscout::Form::TYPE_INSTRUCTION,
              subject: 'bonjour',
              text: 'un message'
            }
          end

          it 'posts the message to the dossier messagerie' do
            expect { subject }.to change(Commentaire, :count).by(1)
            assert_no_enqueued_jobs(only: HelpscoutCreateConversationJob)

            expect(Commentaire.last.email).to eq(user.email)
            expect(Commentaire.last.dossier).to eq(dossier)
            expect(Commentaire.last.body).to include('[bonjour]')
            expect(Commentaire.last.body).to include('un message')

            expect(flash[:notice]).to match('Votre message a été envoyé sur la messagerie de votre dossier.')
            expect(response).to redirect_to messagerie_dossier_path(dossier)
          end
        end
      end

      context "when invisible captcha is filled" do
        subject do
          post :create, params: {
            helpscout_form: { subject: 'bonjour', text: 'un message', type: 'procedure_info' },
            InvisibleCaptcha.honeypots.sample => 'boom'
          }
        end

        it 'does not create a conversation on HelpScout' do
          expect { subject }.not_to change(Commentaire, :count)
          expect(flash[:alert]).to eq(I18n.t('invisible_captcha.sentence_for_humans'))
        end
      end
    end
  end

  context 'signed out' do
    describe "with dossier" do
      it 'should have email field' do
        get :index

        expect(response.status).to eq(200)
        expect(response.body).to have_text("Votre adresse email")
      end
    end

    describe "with dossier" do
      let(:tag) { 'yolo' }

      it 'should fill tags' do
        get :index, params: { tags: [tag] }

        expect(response.status).to eq(200)
        expect(response.body).to include(tag)
      end
    end

    describe 'send form' do
      subject do
        post :create, params: { helpscout_form: params }
      end

      let(:params) { { subject: 'bonjour', email: "me@rspec.net", text: 'un message', type: 'procedure_info' } }

      it 'creates a conversation on HelpScout' do
        expect { subject }.to \
          change(Commentaire, :count).by(0).and \
          have_enqueued_job(HelpscoutCreateConversationJob).with(hash_including(params.except(:type)))

        expect(flash[:notice]).to match('Votre message a été envoyé.')
        expect(response).to redirect_to root_path
      end

      context "when email is invalid" do
        let(:params) { super().merge(email: "me@rspec") }

        it 'creates a conversation on HelpScout' do
          expect { subject }.not_to have_enqueued_job(HelpscoutCreateConversationJob)
          expect(response.body).to include("Le champ « Votre adresse email » est invalide")
          expect(response.body).to include("bonjour")
          expect(response.body).to include("un message")
        end
      end
    end
  end

  context 'contact admin' do
    subject do
      post :create, params: { helpscout_form: params }
    end

    let(:params) { { for_admin: "true", email: "email@pro.fr", subject: 'bonjour', text: 'un message', type: 'admin question', phone: '06' } }

    describe "when form is filled" do
      it "creates a conversation on HelpScout" do
        expect { subject }.to have_enqueued_job(HelpscoutCreateConversationJob).with(hash_including(params.except(:for_admin, :type)))
        expect(flash[:notice]).to match('Votre message a été envoyé.')
      end

      context "with a piece justificative" do
        let(:logo) { fixture_file_upload('spec/fixtures/files/white.png', 'image/png') }
        let(:params) { super().merge(piece_jointe: logo) }

        it "create blob and pass it to conversation job" do
          expect { subject }.to \
            change(ActiveStorage::Blob, :count).by(1).and \
              have_enqueued_job(HelpscoutCreateConversationJob).with(hash_including(blob_id: Integer)).and \
              have_enqueued_job(VirusScannerJob)
        end
      end
    end

    describe "when invisible captcha is filled" do
      subject do
        post :create, params: { helpscout_form: params, InvisibleCaptcha.honeypots.sample => 'boom' }
      end

      it 'does not create a conversation on HelpScout' do
        subject
        expect(flash[:alert]).to eq(I18n.t('invisible_captcha.sentence_for_humans'))
      end
    end
  end
end
