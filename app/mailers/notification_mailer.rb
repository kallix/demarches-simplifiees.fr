# Preview all emails at http://localhost:3000/rails/mailers/notification_mailer

# A Notification is attached as a Comment to the relevant discussion,
# then sent by email to the user.
#
# The subject and body of a Notification can be customized by each demarche.
#
class NotificationMailer < ApplicationMailer
  before_action :set_dossier
  before_action :set_services_publics_plus, only: :send_notification

  helper ServiceHelper
  helper MailerHelper

  layout 'mailers/notifications_layout'
  default from: NO_REPLY_EMAIL

  def send_notification
    @service = @dossier.procedure.service
    @logo_url = procedure_logo_url(@dossier.procedure)
    attachments[@attachment[:filename]] = @attachment[:content] if @attachment.present?
    I18n.with_locale(@dossier.user_locale) do
      mail(subject: @subject, to: @email, template_name: 'send_notification')
    end
  end

  def self.send_en_construction_notification(dossier)
    with(dossier: dossier, state: Dossier.states.fetch(:en_construction)).send_notification
  end

  def self.send_en_instruction_notification(dossier)
    with(dossier: dossier, state: Dossier.states.fetch(:en_instruction)).send_notification
  end

  def self.send_accepte_notification(dossier)
    with(dossier: dossier, state: Dossier.states.fetch(:accepte)).send_notification
  end

  def self.send_refuse_notification(dossier)
    with(dossier: dossier, state: Dossier.states.fetch(:refuse)).send_notification
  end

  def self.send_sans_suite_notification(dossier)
    with(dossier: dossier, state: Dossier.states.fetch(:sans_suite)).send_notification
  end

  def self.send_repasser_en_instruction_notification(dossier)
    with(dossier: dossier, state: Dossier.states.fetch(:en_instruction)).send_notification
  end

  def self.send_pending_correction(dossier)
    with(dossier: dossier).send_notification
  end

  def self.critical_email?(action_name)
    false
  end

  private

  def set_services_publics_plus
    return unless Dossier::TERMINE.include?(params[:state])

    @services_publics_plus_url = ENV['SERVICES_PUBLICS_PLUS_URL'].presence
  end

  def set_dossier
    @dossier = params[:dossier]

    if @dossier.skip_user_notification_email?
      mail.perform_deliveries = false
    else
      I18n.with_locale(@dossier.user_locale) do
        mail_template = @dossier.mail_template_for_state
        mail_template_presenter = MailTemplatePresenterService.new(@dossier)

        @email = @dossier.user_email_for(:notification)
        @rendered_template = mail_template_presenter.safe_body
        @subject = mail_template_presenter.safe_subject
        @actions = mail_template.actions_for_dossier(@dossier)
        @attachment = mail_template.attachment_for_dossier(@dossier)
      end
    end
  end
end
