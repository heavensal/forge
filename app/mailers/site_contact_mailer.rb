# frozen_string_literal: true

class SiteContactMailer < ApplicationMailer
  FORGE_MARK_PATH = Rails.root.join("public/apple-touch-icon.png")

  def forward_inquiry(website:, from_email: nil, from_name: nil, subject: nil, message: nil, fields: {}, photos: [])
    @website = website
    @from_name = from_name
    @from_email = from_email
    @message = message.to_s
    @fields = fields.is_a?(Hash) ? fields.stringify_keys : {}
    # Jobs already queued may still pass the site subject. The delivered subject is the domain line.
    @site_subject = subject

    attach_mark
    attach_photos(photos)

    I18n.with_locale(website.default_locale.presence || I18n.default_locale) do
      @rows = inquiry_rows
      mail(
        to: website.email,
        from: forge_sender,
        subject: "#{I18n.t("contact_form.mailer.subject_lead")} #{website.domain}",
        reply_to: from_email.presence
      )
    end
  end

  private

  def inquiry_rows
    if @fields.any?
      @fields.map { |key, value| [ key.to_s, value.to_s ] }
    else
      rows = []
      rows << [ I18n.t("contact_form.mailer.name"), @from_name.to_s ] if @from_name.present?
      rows << [ I18n.t("contact_form.mailer.email"), @from_email.to_s ] if @from_email.present?
      rows << [ I18n.t("contact_form.mailer.message"), @message ] if @message.present?
      rows
    end
  end

  def attach_mark
    attachments.inline["forge-mark.png"] = {
      mime_type: "image/png",
      content: File.binread(FORGE_MARK_PATH)
    }
  end

  def attach_photos(photos)
    Array(photos).each do |photo|
      item = photo.symbolize_keys
      attachments[item.fetch(:filename)] = {
        mime_type: item.fetch(:content_type),
        content: item.fetch(:data)
      }
    end
  end

  def forge_sender
    parsed = Mail::Address.new(ENV.fetch("MAILER_FROM", "noreply@1344.fr"))
    parsed.display_name = "La Forge"
    parsed.format
  end
end
