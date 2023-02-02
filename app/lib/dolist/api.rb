class Dolist::API
  CONTACT_URL = "https://apiv9.dolist.net/v1/contacts/read?AccountID=%{account_id}"
  EMAIL_LOGS_URL = "https://apiv9.dolist.net/v1/statistics/email/sendings/transactional/search?AccountID=%{account_id}"
  EMAIL_KEY = 7
  DOLIST_WEB_DASHBOARD = "https://campaign.dolist.net/#/%{account_id}/contacts/%{contact_id}/sendings"
  EMAIL_MESSAGES_ADRESSES_REPLIES = "https://apiv9.dolist.net/v1/email/messages/addresses/replies?AccountID=%{account_id}"
  EMAIL_MESSAGES_ADRESSES_PACKSENDERS = "https://apiv9.dolist.net/v1/email/messages/addresses/packsenders?AccountID=%{account_id}"
  EMAIL_SENDING_TRANSACTIONAL = "https://apiv9.dolist.net/v1/email/sendings/transactional?AccountID=%{account_id}"
  EMAIL_SENDING_TRANSACTIONAL_SEARCH = "https://apiv9.dolist.net/v1/email/sendings/transactional/search?AccountID=%{account_id}"

  class_attribute :limit_remaining, :limit_reset_at

  class << self
    def save_rate_limit_headers(headers)
      self.limit_remaining = headers["X-Rate-Limit-Remaining"].to_i
      self.limit_reset_at = Time.zone.at(headers["X-Rate-Limit-Reset"].to_i / 1_000)
    end

    def near_rate_limit?
      return if limit_remaining.nil?

      limit_remaining < 20 # keep 20 requests for non background API calls
    end

    def sleep_until_limit_reset
      return if limit_reset_at.nil? || limit_reset_at.past?

      sleep (limit_reset_at - Time.zone.now).ceil
    end
  end

  def properly_configured?
    client_key.present?
  end

  def send_email(mail)
    url = format(EMAIL_SENDING_TRANSACTIONAL, account_id: account_id)

    body = {
      "TransactionalSending": {
        "Type": "TransactionalService",
        "Contact": {
          "FieldList": [
            {
              "ID": EMAIL_KEY,
              "Value": mail.to.first
            }
          ]
        },
        "Message": {
          "Name": mail['X-Dolist-Message-Name'].value,
          "Subject": mail.subject,
          "SenderID": sender_id,
          "ForceHttp": true,
          "Format": "html",
          "DisableOpenTracking": true,
          "IsTrackingValidated": true
        },
        "MessageContent": {
          "SourceCode": mail_source_code(mail),
          "EncodingType": "UTF8",
          "EnableTrackingDetection": false
        }
      }
    }

    post(url, body.to_json)
  end

  def sent_mails(email_address)
    contact_id = fetch_contact_id(email_address)
    if contact_id.nil?
      Rails.logger.info "Dolist::API: no contact found for email address '#{email_address}'"
      return []
    end

    dolist_messages = fetch_dolist_messages(contact_id)

    dolist_messages.map { |m| to_sent_mail(email_address, contact_id, m) }
  rescue StandardError => e
    Rails.logger.error e.message
    []
  end

  def senders
    url = format(EMAIL_MESSAGES_ADRESSES_PACKSENDERS, account_id: account_id)
    get(url)
  end

  def replies
    url = format(EMAIL_MESSAGES_ADRESSES_REPLIES, account_id: account_id)
    get(url)
  end

  private

  def sender_id
    senders.dig("ItemList", 0, "Sender", "ID")
  end

  def get(url)
    response = Typhoeus.get(url, headers:).tap do
      self.class.save_rate_limit_headers(_1.headers)
    end

    JSON.parse(response.response_body)
  end

  def post(url, body)
    response = Typhoeus.post(url, body:, headers:).tap do
      self.class.save_rate_limit_headers(_1.headers)
    end

    JSON.parse(response.response_body)
  end

  def headers
    {
      "Content-Type": 'application/json',
      "Accept": 'application/json',
      "X-API-Key": client_key
    }
  end

  def client_key
    Rails.application.secrets.dolist[:api_key]
  end

  def account_id
    Rails.application.secrets.dolist[:account_id]
  end

  # https://api.dolist.com/documentation/index.html#/b3A6Mzg0MTQ0MDc-rechercher-un-contact
  def fetch_contact_id(email_address)
    url = format(CONTACT_URL, account_id: account_id)

    body = {
      Query: { FieldValueList: [{ ID: EMAIL_KEY, Value: email_address }] }
    }.to_json

    post(url, body)["ID"]
  end

  # https://api.dolist.com/documentation/index.html#/b3A6Mzg0MTQ4MDk-recuperer-les-statistiques-des-envois-pour-un-contact
  def fetch_dolist_messages(contact_id)
    url = format(EMAIL_LOGS_URL, account_id: account_id)

    body = { SearchQuery: { ContactID: contact_id } }.to_json

    post(url, body)["ItemList"]
  end

  def to_sent_mail(email_address, contact_id, dolist_message)
    SentMail.new(
      from: ENV['DOLIST_NO_REPLY_EMAIL'],
      to: email_address,
      subject: dolist_message['SendingName'],
      delivered_at: Time.zone.parse(dolist_message['SendDate']),
      status: status(dolist_message),
      service_name: 'Dolist',
      external_url: format(DOLIST_WEB_DASHBOARD, account_id: account_id, contact_id: contact_id)
    )
  end

  def status(dolist_message)
    case dolist_message.fetch_values('Status', 'IsDelivered')
    in ['Sent', true]
      "delivered"
    in ['Sent', false]
      "sent (delivered ?)"
    in [status, _]
      status
    end
  end

  def mail_source_code(mail)
    if mail.html_part.nil? && mail.text_part.nil?
      mail.decoded
    else
      mail.html_part.body.decoded
    end
  end
end
