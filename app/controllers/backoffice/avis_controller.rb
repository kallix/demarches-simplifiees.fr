class Backoffice::AvisController < ApplicationController

  before_action :authenticate_gestionnaire!, except: [:sign_up, :create_gestionnaire]
  before_action :check_avis_exists_and_email_belongs_to_avis, only: [:sign_up, :create_gestionnaire]

  def create
    avis = Avis.new(create_params)
    avis.dossier = dossier

    gestionnaire = Gestionnaire.find_by(email: create_params[:email])
    if gestionnaire
      avis.gestionnaire = gestionnaire
      avis.email = nil
    end

    avis.save

    redirect_to backoffice_dossier_path(dossier)
  end

  def update
    if avis.update(update_params)
      flash[:notice] = 'Merci, votre avis a été enregistré.'
    end

    redirect_to backoffice_dossier_path(avis.dossier_id)
  end

  def sign_up
    @email = params[:email]
    @dossier = Avis.includes(:dossier).find(params[:id]).dossier

    render layout: 'new_application'
  end

  def create_gestionnaire
    email = params[:email]
    password = params['gestionnaire']['password']

    gestionnaire = Gestionnaire.new(email: email, password: password)

    if gestionnaire.save
      sign_in(gestionnaire, scope: :gestionnaire)
      Avis.link_avis_to_gestionnaire(gestionnaire)
      avis = Avis.find(params[:id])
      redirect_to url_for(backoffice_dossier_path(avis.dossier_id))
    else
      flash[:alert] = gestionnaire.errors.full_messages.join('<br>')
      redirect_to url_for(avis_sign_up_path(params[:id], email))
    end
  end

  private

  def dossier
    current_gestionnaire.dossiers.find(params[:dossier_id])
  end

  def avis
    current_gestionnaire.avis.find(params[:id])
  end

  def create_params
    params.require(:avis).permit(:email, :introduction)
  end

  def update_params
    params.require(:avis).permit(:answer)
  end

  def check_avis_exists_and_email_belongs_to_avis
    if !Avis.avis_exists_and_email_belongs_to_avis?(params[:id], params[:email])
      redirect_to url_for(root_path)
    end
  end
end
