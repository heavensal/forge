class ApplicationMailer < ActionMailer::Base
  FORGE_MARK_PATH = Rails.root.join("public/apple-touch-icon.png")

  default from: -> { forge_from_address }
  layout "mailer"

  def self.forge_from_address
    parsed = Mail::Address.new(ENV.fetch("MAILER_FROM", "noreply@1344.fr"))
    parsed.display_name = "La Forge"
    parsed.format
  end

  private

  def forge_from_address
    self.class.forge_from_address
  end

  def attach_forge_mark
    attachments.inline["forge-mark.png"] = {
      mime_type: "image/png",
      content: File.binread(self.class::FORGE_MARK_PATH)
    }
  end
end
